//
//  CompressionView.swift
//  hummingbird
//
//  压缩视图
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos

struct CompressionView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isCompressing = false
    @State private var showingSettings = false
    @StateObject private var settings = CompressionSettings()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部选择按钮
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos])) {
                        Label("选择文件", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: startBatchCompression) {
                        Label("开始压缩", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(mediaItems.isEmpty || isCompressing)
                }
                .padding()
                
                Divider()
                
                // 文件列表
                if mediaItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("选择图片或视频开始压缩")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(mediaItems) { item in
                            CompressionItemRow(item: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            withAnimation {
                                mediaItems.remove(atOffsets: indexSet)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("媒体压缩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
    }
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        mediaItems.removeAll()
        
        for item in items {
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
            let mediaItem = MediaItem(pickerItem: item, isVideo: isVideo)
            
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    
                    if isVideo {
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                            .appendingPathExtension("mov")
                        try? data.write(to: tempURL)
                        mediaItem.sourceVideoURL = tempURL
                        
                        let asset = AVURLAsset(url: tempURL)
                        if let videoTrack = asset.tracks(withMediaType: .video).first {
                            let size = videoTrack.naturalSize
                            let transform = videoTrack.preferredTransform
                            let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                            mediaItem.originalResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                        }
                        
                        generateVideoThumbnail(for: mediaItem, url: tempURL)
                    } else {
                        if let image = UIImage(data: data) {
                            mediaItem.thumbnailImage = generateThumbnail(from: image)
                            mediaItem.originalResolution = image.size
                        }
                    }
                }
            }
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
        }
    }
    
    private func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 80, height: 80)) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        var targetSize = size
        if aspectRatio > targetAspectRatio {
            targetSize.height = size.width / aspectRatio
        } else {
            targetSize.width = size.height * aspectRatio
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func generateVideoThumbnail(for item: MediaItem, url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        
        Task {
            do {
                let cgImage = try await generator.image(at: .zero).image
                let thumbnail = UIImage(cgImage: cgImage)
                await MainActor.run {
                    item.thumbnailImage = thumbnail
                }
            } catch {
                print("生成视频缩略图失败: \(error)")
            }
        }
    }
    
    private func startBatchCompression() {
        isCompressing = true
        Task {
            // 重置所有项目状态，以便重新压缩
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedResolution = nil
                    item.compressedVideoURL = nil
                    item.usedBitrate = nil
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await compressItem(item)
            }
            await MainActor.run {
                isCompressing = false
            }
        }
    }
    
    private func compressItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .compressing
            item.progress = 0
        }
        
        if item.isVideo {
            await compressVideo(item)
        } else {
            await compressImage(item)
        }
    }
    
    private func compressImage(_ item: MediaItem) async {
        guard let originalData = item.originalData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        
        do {
            let compressed = try MediaCompressor.compressImage(
                originalData,
                settings: settings
            )
            
            await MainActor.run {
                item.compressedData = compressed
                item.compressedSize = compressed.count
                if let image = UIImage(data: compressed) {
                    item.compressedResolution = image.size
                }
                item.status = .completed
                item.progress = 1.0
            }
        } catch {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func compressVideo(_ item: MediaItem) async {
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        
        await withCheckedContinuation { continuation in
            let exportSession = MediaCompressor.compressVideo(
                at: sourceURL,
                settings: settings,
                outputFileType: .mp4,
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
                            
                            // 使用原始分辨率计算比特率（从 item.originalResolution）
                            if let originalResolution = item.originalResolution {
                                let bitrateBps = settings.calculateBitrate(for: originalResolution)
                                item.usedBitrate = Double(bitrateBps) / 1_000_000.0 // 转换为 Mbps
                                print("✅ 设置比特率: \(item.usedBitrate ?? 0) Mbps (分辨率: \(originalResolution))")
                            }
                            
                            let asset = AVURLAsset(url: url)
                            if let videoTrack = asset.tracks(withMediaType: .video).first {
                                let size = videoTrack.naturalSize
                                let transform = videoTrack.preferredTransform
                                let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                                item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                            }
                            item.status = .completed
                            item.progress = 1.0
                        case .failure(let error):
                            item.status = .failed
                            item.errorMessage = error.localizedDescription
                        }
                        continuation.resume()
                    }
                }
            )
            
            if exportSession == nil {
                Task { @MainActor in
                    item.status = .failed
                    item.errorMessage = "无法创建导出会话"
                    continuation.resume()
                }
            }
        }
    }
}

#Preview {
    CompressionView()
}
