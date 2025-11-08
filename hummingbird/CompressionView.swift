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
                    
                    // 检测原始图片格式（从 PhotosPickerItem 的 contentType 检测）
                    if !isVideo {
                        let isPNG = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.png" ||
                            contentType.conforms(to: .png)
                        }
                        let isHEIC = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.heic" || 
                            contentType.identifier == "public.heif" ||
                            contentType.conforms(to: .heic) ||
                            contentType.conforms(to: .heif)
                        }
                        let isWebP = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "org.webmproject.webp" ||
                            contentType.preferredMIMEType == "image/webp"
                        }
                        
                        if isPNG {
                            mediaItem.originalImageFormat = .png
                            mediaItem.fileExtension = "png"
                            print("📋 [格式检测] PhotosPickerItem 格式: PNG")
                        } else if isHEIC {
                            mediaItem.originalImageFormat = .heic
                            mediaItem.fileExtension = "heic"
                            print("📋 [格式检测] PhotosPickerItem 格式: HEIC")
                        } else if isWebP {
                            mediaItem.originalImageFormat = .webp
                            mediaItem.fileExtension = "webp"
                            print("📋 [格式检测] PhotosPickerItem 格式: WebP")
                        } else {
                            mediaItem.originalImageFormat = .jpeg
                            mediaItem.fileExtension = "jpg"
                            print("📋 [格式检测] PhotosPickerItem 格式: JPEG")
                        }
                    }
                    
                    if isVideo {
                        // 检测视频格式
                        let isMOV = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "com.apple.quicktime-movie" ||
                            contentType.conforms(to: .quickTimeMovie)
                        }
                        let isMP4 = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.mpeg-4" ||
                            contentType.conforms(to: .mpeg4Movie)
                        }
                        
                        if isMOV {
                            mediaItem.fileExtension = "mov"
                        } else if isMP4 {
                            mediaItem.fileExtension = "mp4"
                        } else {
                            mediaItem.fileExtension = "video"
                        }
                        
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
        
        // 显示压缩开始状态
        await MainActor.run {
            item.status = .compressing
            item.progress = 0.1
        }
        
        // 短暂延迟，让用户看到"压缩中"状态
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        
        do {
            // 更新进度：准备压缩
            await MainActor.run {
                item.progress = 0.3
            }
            
            // 根据设置决定输出格式
            let outputFormat: ImageFormat
            if item.originalImageFormat == .png {
                // PNG 始终保持 PNG 格式
                outputFormat = .png
            } else if item.originalImageFormat == .webp {
                // WebP 始终保持 WebP 格式
                outputFormat = .webp
            } else if settings.preferHEIC && item.originalImageFormat == .heic {
                // 开启 HEIC 优先，且原图是 HEIC，保持 HEIC
                outputFormat = .heic
            } else {
                // 否则使用 JPEG (MozJPEG)
                outputFormat = .jpeg
            }
            
            // 更新进度：正在压缩
            await MainActor.run {
                item.progress = 0.5
            }
            
            let compressed = try await MediaCompressor.compressImage(
                originalData,
                settings: settings,
                preferredFormat: outputFormat,
                progressHandler: { progress in
                    Task { @MainActor in
                        // 将压缩进度映射到 0.5-0.9 范围
                        item.progress = 0.5 + (progress * 0.4)
                    }
                }
            )
            
            // 更新进度：压缩完成，处理结果
            await MainActor.run {
                item.progress = 0.9
            }
            
            await MainActor.run {
                // 智能判断：如果压缩后反而变大，保留原图
                if compressed.count >= originalData.count {
                    print("⚠️ [压缩判断] 压缩后大小 (\(compressed.count) bytes) >= 原图 (\(originalData.count) bytes)，保留原图")
                    item.compressedData = originalData
                    item.compressedSize = originalData.count
                    item.outputImageFormat = item.originalImageFormat  // 保持原格式
                } else {
                    print("✅ [压缩判断] 压缩成功，从 \(originalData.count) bytes 减少到 \(compressed.count) bytes")
                    item.compressedData = compressed
                    item.compressedSize = compressed.count
                    item.outputImageFormat = outputFormat  // 使用压缩后的格式
                }
                
                if let image = UIImage(data: item.compressedData!) {
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
                            // 获取压缩后的文件大小
                            let compressedSize: Int
                            if let data = try? Data(contentsOf: url) {
                                compressedSize = data.count
                            } else {
                                compressedSize = 0
                            }
                            
                            // 智能判断：如果压缩后反而变大，保留原视频
                            if compressedSize >= item.originalSize {
                                print("⚠️ [视频压缩判断] 压缩后大小 (\(compressedSize) bytes) >= 原视频 (\(item.originalSize) bytes)，保留原视频")
                                
                                // 使用原视频
                                item.compressedVideoURL = sourceURL
                                item.compressedSize = item.originalSize
                                item.compressedResolution = item.originalResolution
                                
                                // 清理压缩后的临时文件
                                try? FileManager.default.removeItem(at: url)
                            } else {
                                print("✅ [视频压缩判断] 压缩成功，从 \(item.originalSize) bytes 减少到 \(compressedSize) bytes")
                                
                                // 使用压缩后的视频
                                item.compressedVideoURL = url
                                item.compressedSize = compressedSize
                                
                                let asset = AVURLAsset(url: url)
                                if let videoTrack = asset.tracks(withMediaType: .video).first {
                                    let size = videoTrack.naturalSize
                                    let transform = videoTrack.preferredTransform
                                    let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                                    item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                                }
                            }
                            
                            // 使用原始分辨率计算比特率（从 item.originalResolution）
                            if let originalResolution = item.originalResolution {
                                let bitrateBps = settings.calculateBitrate(for: originalResolution)
                                item.usedBitrate = Double(bitrateBps) / 1_000_000.0 // 转换为 Mbps
                                print("✅ 设置比特率: \(item.usedBitrate ?? 0) Mbps (分辨率: \(originalResolution))")
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
