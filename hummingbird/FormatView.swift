//
//  FormatView.swift
//  hummingbird
//
//  格式转换视图
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import SDWebImageWebPCoder

struct FormatView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isConverting = false
    @State private var targetImageFormat: ImageFormat = .jpeg
    @State private var targetVideoFormat: VideoFormat = .mp4
    
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
                    
                    Button(action: startBatchConversion) {
                        Label("开始转换", systemImage: "arrow.triangle.2.circlepath")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(mediaItems.isEmpty || isConverting)
                }
                .padding()
                
                // 格式设置
                VStack(spacing: 12) {
                    HStack {
                        Text("图片格式")
                            .font(.headline)
                        Spacer()
                        Picker("图片格式", selection: $targetImageFormat) {
                            Text("JPEG").tag(ImageFormat.jpeg)
                            Text("PNG").tag(ImageFormat.png)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    
                    HStack {
                        Text("视频格式")
                            .font(.headline)
                        Spacer()
                        Picker("视频格式", selection: $targetVideoFormat) {
                            Text("MP4").tag(VideoFormat.mp4)
                            Text("MOV").tag(VideoFormat.mov)
                            Text("M4V").tag(VideoFormat.m4v)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // 文件列表
                if mediaItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("选择图片或视频进行格式转换")
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
                            withAnimation {
                                mediaItems.remove(atOffsets: indexSet)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("格式转换")
            .navigationBarTitleDisplayMode(.inline)
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
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        mediaItems.removeAll()
        
        for item in items {
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
            let mediaItem = MediaItem(pickerItem: item, isVideo: isVideo)
            
            // 先添加到列表，显示加载状态
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            if isVideo {
                // 视频优化：延迟加载
                await loadVideoItemOptimized(item, mediaItem)
            } else {
                // 图片：正常加载
                await loadImageItem(item, mediaItem)
            }
        }
    }
    
    private func loadImageItem(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
                
                // 检测原始图片格式（只处理图片）
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
                } else if isHEIC {
                    mediaItem.originalImageFormat = .heic
                    mediaItem.fileExtension = "heic"
                } else if isWebP {
                    mediaItem.originalImageFormat = .webp
                    mediaItem.fileExtension = "webp"
                } else {
                    mediaItem.originalImageFormat = .jpeg
                    mediaItem.fileExtension = "jpg"
                }
                
                if let image = UIImage(data: data) {
                    mediaItem.thumbnailImage = generateThumbnail(from: image)
                    mediaItem.originalResolution = image.size
                }
                
                // 加载完成，设置为等待状态
                mediaItem.status = .pending
            }
        }
    }
    
    private func loadVideoItemOptimized(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        // 检测视频格式
        await MainActor.run {
            // 首先尝试从文件扩展名判断
            if let ext = item.supportedContentTypes.first?.preferredFilenameExtension?.lowercased() {
                mediaItem.fileExtension = ext
            } else {
                // 回退到类型检测
                let isMP4 = item.supportedContentTypes.contains { contentType in
                    contentType.identifier == "public.mpeg-4" ||
                    contentType.conforms(to: .mpeg4Movie)
                }
                let isM4V = item.supportedContentTypes.contains { contentType in
                    contentType.identifier == "com.apple.m4v-video"
                }
                let isMOV = item.supportedContentTypes.contains { contentType in
                    contentType.identifier == "com.apple.quicktime-movie" ||
                    contentType.conforms(to: .quickTimeMovie)
                }
                
                if isMP4 {
                    mediaItem.fileExtension = "mp4"
                } else if isM4V {
                    mediaItem.fileExtension = "m4v"
                } else if isMOV {
                    mediaItem.fileExtension = "mov"
                } else {
                    mediaItem.fileExtension = "video"
                }
            }
        }
        
        // 优化：使用 URL 方式加载视频
        if let url = try? await item.loadTransferable(type: URL.self) {
            await MainActor.run {
                mediaItem.sourceVideoURL = url
                
                // 快速获取文件大小
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
                    mediaItem.originalSize = fileSize
                }
                
                // 异步获取视频信息和缩略图
                Task {
                    await loadVideoMetadata(for: mediaItem, url: url)
                }
            }
        } else {
            // 回退到数据加载方式
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                        .appendingPathExtension(mediaItem.fileExtension)
                    try? data.write(to: tempURL)
                    mediaItem.sourceVideoURL = tempURL
                    
                    Task {
                        await loadVideoMetadata(for: mediaItem, url: tempURL)
                    }
                }
            }
        }
    }
    
    private func loadVideoMetadata(for mediaItem: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        
        // 异步加载视频轨道信息和时长
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = tracks.first {
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                
                await MainActor.run {
                    mediaItem.originalResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                }
            }
            
            // 加载视频时长
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            await MainActor.run {
                mediaItem.duration = durationSeconds
            }
        } catch {
            print("加载视频轨道信息失败: \(error)")
        }
        
        // 异步生成缩略图
        await generateVideoThumbnailOptimized(for: mediaItem, url: url)
        
        // 视频元数据加载完成，设置为等待状态
        await MainActor.run {
            mediaItem.status = .pending
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
    
    private func generateVideoThumbnailOptimized(for item: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        
        // 优化：设置更快的缩略图生成选项
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
        
        do {
            let cgImage = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
            let thumbnail = UIImage(cgImage: cgImage)
            await MainActor.run {
                item.thumbnailImage = thumbnail
            }
        } catch {
            print("生成视频缩略图失败: \(error)")
            // 设置默认视频图标
            await MainActor.run {
                item.thumbnailImage = UIImage(systemName: "video.fill")
            }
        }
    }
    
    private func startBatchConversion() {
        isConverting = true
        
        Task {
            // 重置所有项目状态
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedVideoURL = nil
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await convertItem(item)
            }
            await MainActor.run {
                isConverting = false
            }
        }
    }
    
    private func convertItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        
        if item.isVideo {
            await convertVideo(item)
        } else {
            await convertImage(item)
        }
    }
    
    private func convertImage(_ item: MediaItem) async {
        guard let originalData = item.originalData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        
        guard let image = UIImage(data: originalData) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法解码图片"
            }
            return
        }
        
        await MainActor.run {
            item.progress = 0.3
        }
        
        // 转换为目标格式
        let convertedData: Data?
        let outputFormat = targetImageFormat
        
        switch outputFormat {
        case .jpeg:
            convertedData = image.jpegData(compressionQuality: 1.0)
            
        case .png:
            convertedData = image.pngData()
            
        case .webp:
            let webpCoder = SDImageWebPCoder.shared
            convertedData = webpCoder.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: 1.0])
            
        case .heic:
            // HEIC 格式
            if #available(iOS 11.0, *) {
                let mutableData = NSMutableData()
                if let cgImage = image.cgImage,
                   let destination = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil) {
                    let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 1.0]
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        convertedData = mutableData as Data
                    } else {
                        convertedData = nil
                    }
                } else {
                    convertedData = nil
                }
            } else {
                convertedData = nil
            }
        }
        
        await MainActor.run {
            item.progress = 0.8
        }
        
        guard let data = convertedData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "格式转换失败"
            }
            return
        }
        
        await MainActor.run {
            item.compressedData = data
            item.compressedSize = data.count
            item.outputImageFormat = outputFormat
            item.compressedResolution = image.size
            item.status = .completed
            item.progress = 1.0
            
            print("✅ [格式转换] \(item.originalImageFormat?.rawValue ?? "未知") -> \(outputFormat.rawValue) - 大小: \(data.count) bytes")
        }
    }
    
    private func convertVideo(_ item: MediaItem) async {
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法创建导出会话"
            }
            return
        }
        
        let outputFormat = targetVideoFormat
        let fileExtension = outputFormat.fileExtension
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("converted_\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFormat.avFileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            Task { @MainActor in
                item.progress = exportSession.progress
            }
            if exportSession.status != .exporting { t.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        
        await exportSession.export()
        
        await MainActor.run {
            switch exportSession.status {
            case .completed:
                item.compressedVideoURL = outputURL
                if let data = try? Data(contentsOf: outputURL) {
                    item.compressedSize = data.count
                }
                
                let resultAsset = AVURLAsset(url: outputURL)
                if let videoTrack = resultAsset.tracks(withMediaType: .video).first {
                    let size = videoTrack.naturalSize
                    let transform = videoTrack.preferredTransform
                    let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                    item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                }
                
                item.outputVideoFormat = fileExtension
                item.status = .completed
                item.progress = 1.0
                
                print("✅ [格式转换] 视频 -> \(outputFormat.rawValue) - 大小: \(item.compressedSize) bytes")
            default:
                item.status = .failed
                item.errorMessage = exportSession.error?.localizedDescription ?? "转换失败"
            }
        }
    }
}

// 视频格式枚举
enum VideoFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case m4v = "M4V"
    
    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .m4v: return "m4v"
        }
    }
    
    var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .m4v: return .m4v
        }
    }
}

#Preview {
    FormatView()
}
