//
//  VideoToAnimationView.swift
//  hummingbird
//
//  Created by Agent on 2025/11/21.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct VideoToAnimationView: View {
    let initialFormat: FFmpegAnimationConverter.AnimationFormat
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isConverting = false
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var targetFormat: FFmpegAnimationConverter.AnimationFormat
    
    init(format: FFmpegAnimationConverter.AnimationFormat) {
        self.initialFormat = format
        _targetFormat = State(initialValue: format)
    }
    
    private var hasLoadingItems: Bool {
        mediaItems.contains { $0.status == .loading }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Buttons
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Menu {
                        Button(action: { showingPhotoPicker = true }) {
                            Label("Select from Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        
                        Button(action: { showingFilePicker = true }) {
                            Label("Select from Files", systemImage: "folder.fill")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Files")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isConverting || hasLoadingItems)
                    
                    Button(action: startConversion) {
                        HStack(spacing: 6) {
                            if isConverting || hasLoadingItems {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isConverting ? "Processing" : hasLoadingItems ? "Loading" : "Start")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mediaItems.isEmpty || isConverting || hasLoadingItems ? .gray : .green)
                    .disabled(mediaItems.isEmpty || isConverting || hasLoadingItems)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemGroupedBackground))
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            
            // Settings Area
            VStack(spacing: 0) {
                HStack {
                    Text("Target Format")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $targetFormat) {
                        Text("WebP").tag(FFmpegAnimationConverter.AnimationFormat.webp)
                        Text("AVIF").tag(FFmpegAnimationConverter.AnimationFormat.avif)
                        Text("GIF").tag(FFmpegAnimationConverter.AnimationFormat.gif)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            .background(Color(uiColor: .systemBackground))
            
            // File List
            if mediaItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select videos to convert")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mediaItems) { item in
                        FormatItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.visible)
                    }
                    .onDelete { indexSet in
                        guard !isConverting && !hasLoadingItems else { return }
                        withAnimation {
                            mediaItems.remove(atOffsets: indexSet)
                        }
                    }
                    .deleteDisabled(isConverting || hasLoadingItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Video to Animation")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .videos)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.movie, .video], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                Task {
                    await loadFilesFromURLs(urls)
                }
            } catch {
                print("File selection failed: \(error.localizedDescription)")
            }
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await loadSelectedItems(newItems)
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
    }
    
    private func startConversion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isConverting = true
        }
        
        Task {
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedVideoURL = nil
                    item.compressedSize = 0
                    item.errorMessage = nil
                    item.infoMessage = nil
                }
            }
            
            for item in mediaItems {
                await convertItem(item)
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConverting = false
                }
            }
        }
    }
    
    private func convertItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
            item.processingStartTime = Date()  // Track start time for estimation
        }
        
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "Source video not found"
            }
            return
        }
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("anim_\(UUID().uuidString)")
            .appendingPathExtension(targetFormat.fileExtension)
            
        await withCheckedContinuation { continuation in
            FFmpegAnimationConverter.convert(
                inputURL: sourceURL,
                outputURL: outputURL,
                format: targetFormat,
                progressHandler: { progress in
                    Task { @MainActor in
                        item.progress = progress
                    }
                },
                completion: { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let url):
                            item.compressedVideoURL = url
                            if let data = try? Data(contentsOf: url) {
                                item.compressedSize = data.count
                            }
                            item.status = .completed
                            item.progress = 1.0
                            item.outputVideoFormat = targetFormat.rawValue
                            item.infoMessage = "Converted to \(targetFormat.rawValue.uppercased())"
                            
                        case .failure(let error):
                            item.status = .failed
                            item.errorMessage = error.localizedDescription
                        }
                        continuation.resume()
                    }
                }
            )
        }
    }
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for item in items {
            let mediaItem = MediaItem(pickerItem: item, isVideo: true)
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            // Load video data
            if let url = try? await item.loadTransferable(type: URL.self) {
                await MainActor.run {
                    mediaItem.sourceVideoURL = url
                    if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
                        mediaItem.originalSize = fileSize
                    }
                    mediaItem.status = .pending
                    mediaItem.fileExtension = url.pathExtension.lowercased()
                }
                // Load thumbnail
                await loadVideoMetadata(for: mediaItem, url: url)
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                // Handle data loading (create temp file)
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                    .appendingPathExtension("mp4") // Default to mp4 if unknown
                
                do {
                    try data.write(to: tempURL)
                    await MainActor.run {
                        mediaItem.sourceVideoURL = tempURL
                        mediaItem.originalSize = data.count
                        mediaItem.status = .pending
                        mediaItem.fileExtension = "mp4"
                    }
                    await loadVideoMetadata(for: mediaItem, url: tempURL)
                } catch {
                    await MainActor.run {
                        mediaItem.status = .failed
                        mediaItem.errorMessage = "Failed to save video"
                    }
                }
            }
        }
    }
    
    private func loadFilesFromURLs(_ urls: [URL]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let mediaItem = MediaItem(pickerItem: nil, isVideo: true)
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            do {
                let data = try Data(contentsOf: url)
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                    .appendingPathExtension(url.pathExtension)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    mediaItem.sourceVideoURL = tempURL
                    mediaItem.originalSize = data.count
                    mediaItem.fileExtension = url.pathExtension.lowercased()
                    mediaItem.status = .pending
                }
                await loadVideoMetadata(for: mediaItem, url: tempURL)
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadVideoMetadata(for item: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        
        // Load duration
        if let duration = try? await asset.load(.duration) {
            await MainActor.run {
                item.duration = duration.seconds
            }
        }
        
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            // Load resolution
            if let size = try? await track.load(.naturalSize) {
                await MainActor.run {
                    item.originalResolution = size
                }
            }
            
            // Load frame rate
            if let frameRate = try? await track.load(.nominalFrameRate) {
                await MainActor.run {
                    item.frameRate = Double(frameRate)
                }
            }
        }
        
        // Generate thumbnail
        FFmpegVideoCompressor.extractThumbnail(from: url) { result in
            if case .success(let thumbURL) = result,
               let data = try? Data(contentsOf: thumbURL),
               let image = UIImage(data: data) {
                Task { @MainActor in
                    item.thumbnailImage = image
                }
            }
        }
    }
}
