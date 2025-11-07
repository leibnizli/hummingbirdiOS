//
//  ContentView.swift
//  hummingbird
//
//  Created by admin on 2025/11/4.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos

struct ContentView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isCompressing = false
    
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(mediaItems) { item in
                                MediaItemRow(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("媒体压缩")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await loadSelectedItems(newItems) }
        }
    }
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        mediaItems.removeAll()
        
        for item in items {
            // 判断是图片还是视频
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
            let mediaItem = MediaItem(pickerItem: item, isVideo: isVideo)
            
            // 加载数据
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    
                    if isVideo {
                        // 视频：保存到临时文件
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                            .appendingPathExtension("mov")
                        try? data.write(to: tempURL)
                        mediaItem.sourceVideoURL = tempURL
                        
                        // 生成视频缩略图
                        generateVideoThumbnail(for: mediaItem, url: tempURL)
                    } else {
                        // 图片：生成缩略图
                        if let image = UIImage(data: data) {
                            mediaItem.thumbnailImage = generateThumbnail(from: image)
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
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func generateVideoThumbnail(for item: MediaItem, url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 80, height: 80)
        
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
            for item in mediaItems where item.status == .pending {
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
                options: .init(maxKilobytes: 800, preferHEIC: true)
            )
            
            await MainActor.run {
                item.compressedData = compressed
                item.compressedSize = compressed.count
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
                preset: AVAssetExportPresetMediumQuality,
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

// MARK: - 媒体项行视图
struct MediaItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingSaveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 预览图
                Group {
                    if let thumbnail = item.thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // 信息区域
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: item.isVideo ? "video.circle.fill" : "photo.circle.fill")
                            .foregroundStyle(item.isVideo ? .blue : .green)
                        Text(item.isVideo ? "视频" : "图片")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // 状态标识
                        statusBadge
                    }
                    
                    // 文件大小信息
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("原始: \(item.formatBytes(item.originalSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("压缩后: \(item.formatBytes(item.compressedSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("减少: \(item.formatBytes(item.savedSize))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("压缩率: \(String(format: "%.1f%%", item.compressionRatio * 100))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Text("大小: \(item.formatBytes(item.originalSize))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 进度条
                    if item.status == .compressing {
                        ProgressView(value: Double(item.progress))
                            .tint(.blue)
                    }
                    
                    // 错误信息
                    if let error = item.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }
            
            // 保存按钮
            if item.status == .completed {
                Button(action: { saveToPhotos(item) }) {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .alert("保存成功", isPresented: $showingSaveAlert) {
                    Button("确定", role: .cancel) { }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Label("等待中", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .compressing:
            Label("压缩中", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.blue)
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
    
    private func saveToPhotos(_ item: MediaItem) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                print("相册权限被拒绝")
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if item.isVideo, let url = item.compressedVideoURL {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else if let data = item.compressedData, let image = UIImage(data: data) {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }
                await MainActor.run {
                    showingSaveAlert = true
                }
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
