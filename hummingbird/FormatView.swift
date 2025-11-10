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
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var showingSettings = false
    @StateObject private var settings = FormatSettings()
    
    // 检查是否有媒体项正在加载
    private var hasLoadingItems: Bool {
        mediaItems.contains { $0.status == .loading }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部选择按钮
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // 左侧：下拉菜单选择来源
                        Menu {
                            Button(action: { showingPhotoPicker = true }) {
                                Label("从相册选择", systemImage: "photo.on.rectangle.angled")
                            }
                            
                            Button(action: { showingFilePicker = true }) {
                                Label("从文件选择", systemImage: "folder.fill")
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("添加文件")
                                    .font(.system(size: 15, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        // 右侧：开始按钮
                        Button(action: startBatchConversion) {
                            HStack(spacing: 6) {
                                if isConverting || hasLoadingItems {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                Text(isConverting ? "处理中" : hasLoadingItems ? "加载中" : "开始转换")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(mediaItems.isEmpty || isConverting || hasLoadingItems ? .gray : .orange)
                        .disabled(mediaItems.isEmpty || isConverting || hasLoadingItems)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemGroupedBackground))
                    
                    // 底部分隔线
                    Rectangle()
                        .fill(Color(uiColor: .separator).opacity(0.5))
                        .frame(height: 0.5)
                }
                
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            FormatSettingsView(settings: settings)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.image, .movie, .video], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task {
                    await loadFilesFromURLs(urls)
                }
            case .failure(let error):
                print("文件选择失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFilesFromURLs(_ urls: [URL]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for url in urls {
            // 验证文件是否可访问
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 检查文件类型
            let isVideo = UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false
            let mediaItem = MediaItem(pickerItem: nil, isVideo: isVideo)
            
            // 添加到列表
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            do {
                // 读取文件数据
                let data = try Data(contentsOf: url)
                
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    mediaItem.fileExtension = url.pathExtension.lowercased()
                    
                    // 设置格式
                    if isVideo {
                        // 视频文件
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                            .appendingPathExtension(url.pathExtension)
                        try? data.write(to: tempURL)
                        mediaItem.sourceVideoURL = tempURL
                    } else if let type = UTType(filenameExtension: url.pathExtension) {
                        if type.conforms(to: .png) {
                            mediaItem.originalImageFormat = .png
                        } else if type.conforms(to: .heic) {
                            mediaItem.originalImageFormat = .heic
                        } else if type.identifier == "org.webmproject.webp" {
                            mediaItem.originalImageFormat = .webp
                        } else {
                            mediaItem.originalImageFormat = .jpeg
                        }
                    }
                    
                    // 如果是图片，生成缩略图和获取分辨率
                    if !isVideo, let image = UIImage(data: data) {
                        mediaItem.thumbnailImage = generateThumbnail(from: image)
                        mediaItem.originalResolution = image.size
                        mediaItem.status = .pending
                    }
                }
                
                // 如果是视频，处理视频相关信息
                if isVideo, let tempURL = mediaItem.sourceVideoURL {
                    await loadVideoMetadata(for: mediaItem, url: tempURL)
                }
            } catch {
                print("读取文件失败: \(error.localizedDescription)")
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = "读取文件失败"
                }
            }
        }
    }
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
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
                
                // 立即设置为 pending 状态，让用户看到视频已添加
                mediaItem.status = .pending
                
                // 在后台异步获取视频信息和缩略图
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
                    
                    // 立即设置为 pending 状态
                    mediaItem.status = .pending
                    
                    // 在后台异步获取视频信息和缩略图
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
        print("[FormatView] startBatchConversion 被调用")
        print("[FormatView] 媒体项数量: \(mediaItems.count)")
        print("[FormatView] isConverting 当前状态: \(isConverting)")
        
        // 防止重复点击
        guard !isConverting else {
            print("⚠️ [FormatView] 已在转换中，忽略重复点击")
            return
        }
        
        // 使用 withAnimation 确保状态变化有动画效果
        withAnimation(.easeInOut(duration: 0.2)) {
            isConverting = true
        }
        print("[FormatView] isConverting 设置为 true")
        
        Task {
            print("[FormatView] Task 开始执行")
            
            // 重置所有项目状态
            await MainActor.run {
                print("[FormatView] 重置所有项目状态")
                for (index, item) in mediaItems.enumerated() {
                    print("  - 项目 \(index): isVideo=\(item.isVideo), 原始大小=\(item.originalSize)")
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedVideoURL = nil
                    item.errorMessage = nil
                }
            }
            
            print("[FormatView] 开始逐个转换项目")
            for (index, item) in mediaItems.enumerated() {
                print("[FormatView] 转换项目 \(index)")
                await convertItem(item)
                print("[FormatView] 项目 \(index) 转换完成，状态: \(item.status)")
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConverting = false
                }
                print("[FormatView] 所有转换完成，isConverting 设置为 false")
            }
        }
    }
    
    private func convertItem(_ item: MediaItem) async {
        print("🟢 [convertItem] 开始转换项目，isVideo: \(item.isVideo)")
        
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        print("🟢 [convertItem] 状态设置为 processing")
        
        if item.isVideo {
            print("🟢 [convertItem] 这是视频，调用 convertVideo")
            await convertVideo(item)
        } else {
            print("🟢 [convertItem] 这是图片，调用 convertImage")
            print("🟢 [convertItem] 目标格式: \(settings.targetImageFormat.rawValue)")
            await convertImage(item)
        }
        print("🟢 [convertItem] 转换完成")
    }
    
    private func convertImage(_ item: MediaItem) async {
        print("[convertImage] 开始图片转换")
        
        guard let originalData = item.originalData else {
            print(" [convertImage] 无法加载原始图片数据")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        print("[convertImage] 原始数据大小: \(originalData.count) bytes")
        
        // 加载图片并修正方向
        guard var image = UIImage(data: originalData) else {
            print(" [convertImage] 无法解码图片")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法解码图片"
            }
            return
        }
        print("[convertImage] 图片解码成功，尺寸: \(image.size)")
        
        // 修正图片方向，避免旋转问题
        image = image.fixOrientation()
        print("[convertImage] 图片方向已修正")
        
        await MainActor.run {
            item.progress = 0.3
        }
        
        // 转换为目标格式
        let convertedData: Data?
        let outputFormat = settings.targetImageFormat
        print("[convertImage] 目标格式: \(outputFormat.rawValue)")
        
        switch outputFormat {
        case .jpeg:
            print("[convertImage] 转换为 JPEG")
            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.jpeg.identifier as CFString, 1, nil) else {
                print(" [convertImage] 无法创建 JPEG destination")
                convertedData = nil
                break
            }
            
            // 配置转换选项
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 1.0,
                kCGImageDestinationOptimizeColorForSharing: true
            ]
            
            if let cgImage = image.cgImage {
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    convertedData = destinationData as Data
                    print("[convertImage] JPEG 转换成功，大小: \(destinationData.length) bytes")
                } else {
                    print(" [convertImage] JPEG finalize 失败")
                    convertedData = nil
                }
            } else {
                print(" [convertImage] 无法获取 cgImage")
                convertedData = nil
            }
            
        case .png:
            print("[convertImage] 转换为 PNG")
            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.png.identifier as CFString, 1, nil) else {
                print(" [convertImage] 无法创建 PNG destination")
                convertedData = nil
                break
            }
            
            // PNG 特定选项
            let options: [CFString: Any] = [
                kCGImageDestinationOptimizeColorForSharing: true
            ]
            
            if let cgImage = image.cgImage {
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    convertedData = destinationData as Data
                    print("[convertImage] PNG 转换成功，大小: \(destinationData.length) bytes")
                } else {
                    print(" [convertImage] PNG finalize 失败")
                    convertedData = nil
                }
            } else {
                print(" [convertImage] 无法获取 cgImage")
                convertedData = nil
            }
            
        case .webp:
            print("[convertImage] 转换为 WebP")
            let webpCoder = SDImageWebPCoder.shared
            let options: [SDImageCoderOption: Any] = [
                .encodeCompressionQuality: 1.0
            ]
            convertedData = webpCoder.encodedData(with: image, format: .webP, options: options)
            if let data = convertedData {
                print("[convertImage] WebP 转换成功，大小: \(data.count) bytes")
            } else {
                print(" [convertImage] WebP 转换失败")
            }
            
        case .heic:
            print("[convertImage] 转换为 HEIC")
            if #available(iOS 11.0, *) {
                let destinationData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(destinationData, AVFileType.heic as CFString, 1, nil) else {
                    print(" [convertImage] 无法创建 HEIC destination")
                    convertedData = nil
                    break
                }
                
                // HEIC 特定选项
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 1.0,
                    kCGImageDestinationOptimizeColorForSharing: true
                ]
                
                if let cgImage = image.cgImage {
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        convertedData = destinationData as Data
                        print("[convertImage] HEIC 转换成功，大小: \(destinationData.length) bytes")
                    } else {
                        print(" [convertImage] HEIC finalize 失败")
                        convertedData = nil
                    }
                } else {
                    print(" [convertImage] 无法获取 cgImage")
                    convertedData = nil
                }
            } else {
                print(" [convertImage] iOS 版本不支持 HEIC")
                convertedData = nil
            }
        }
        
        await MainActor.run {
            item.progress = 0.8
        }
        
        guard let data = convertedData else {
            print(" [convertImage] 转换失败，convertedData 为 nil")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "格式转换失败"
            }
            return
        }
        
        print("[convertImage] 转换成功，准备保存结果")
        await MainActor.run {
            item.compressedData = data
            item.compressedSize = data.count
            item.outputImageFormat = outputFormat
            item.compressedResolution = image.size
            item.status = .completed
            item.progress = 1.0
            
            print("[格式转换] \(item.originalImageFormat?.rawValue ?? "未知") -> \(outputFormat.rawValue) - 大小: \(data.count) bytes")
        }
        print("[convertImage] 图片转换完成")
    }
    
    private func convertVideo(_ item: MediaItem) async {
        print("[convertVideo] 开始视频转换")
        
        guard let sourceURL = item.sourceVideoURL else {
            print(" [convertVideo] 无法加载原始视频 URL")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        print("[convertVideo] 源视频 URL: \(sourceURL.path)")
        
        let asset = AVURLAsset(url: sourceURL)
        
        // 获取原始视频信息
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            print(" [convertVideo] 无法获取视频轨道信息")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法获取视频轨道信息"
            }
            return
        }
        print("[convertVideo] 视频轨道获取成功")
        
        // 选择合适的预设
        let presetName: String
        if settings.useHEVC && AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality) {
            presetName = AVAssetExportPresetHEVCHighestQuality
            print("[convertVideo] 使用 HEVC 预设")
        } else {
            presetName = AVAssetExportPresetHighestQuality
            print("[convertVideo] 使用标准高质量预设")
        }
        
        // 创建导出会话
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
            print(" [convertVideo] 无法创建导出会话")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法创建导出会话"
            }
            return
        }
        print("[convertVideo] 导出会话创建成功")
        
        let fileExtension = settings.targetVideoFormat
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("converted_\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        
        print("[convertVideo] 目标格式: \(fileExtension)")
        print("[convertVideo] 输出 URL: \(outputURL.path)")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = {
            switch fileExtension {
            case "mov": return .mov
            case "m4v": return .m4v
            default: return .mp4
            }
        }()
        exportSession.shouldOptimizeForNetworkUse = true
        print("[convertVideo] 导出会话配置完成")
        
        // 使用 AVFoundation 自动处理旋转和方向
        // 通过 videoComposition(withPropertiesOf:) 可以自动应用正确的变换
        do {
            let videoComposition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
            exportSession.videoComposition = videoComposition
            print("[convertVideo] 视频合成创建成功")
        } catch {
            print("⚠️ [convertVideo] 创建视频合成失败，将使用默认设置: \(error)")
            // 如果自动创建失败，不设置 videoComposition，让系统使用默认处理
        }
        
        print("[convertVideo] 开始导出视频")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            Task { @MainActor in
                item.progress = exportSession.progress
            }
            if exportSession.status != .exporting { t.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        
        await exportSession.export()
        print("[convertVideo] 导出完成，状态: \(exportSession.status.rawValue)")
        
        await MainActor.run {
            switch exportSession.status {
            case .completed:
                print("[convertVideo] 视频导出成功")
                item.compressedVideoURL = outputURL
                if let data = try? Data(contentsOf: outputURL) {
                    item.compressedSize = data.count
                    print("[convertVideo] 输出文件大小: \(data.count) bytes")
                }
                
                let resultAsset = AVURLAsset(url: outputURL)
                if let videoTrack = resultAsset.tracks(withMediaType: .video).first {
                    let size = videoTrack.naturalSize
                    let transform = videoTrack.preferredTransform
                    let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                    item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                    print("[convertVideo] 输出分辨率: \(item.compressedResolution!)")
                }
                
                item.outputVideoFormat = fileExtension
                item.status = .completed
                item.progress = 1.0
                
                print("[格式转换] 视频 -> \(fileExtension.uppercased()) - 大小: \(item.compressedSize) bytes")
            default:
                print(" [convertVideo] 视频导出失败，状态: \(exportSession.status.rawValue)")
                if let error = exportSession.error {
                    print(" [convertVideo] 错误信息: \(error.localizedDescription)")
                }
                item.status = .failed
                item.errorMessage = exportSession.error?.localizedDescription ?? "转换失败"
            }
        }
        print("[convertVideo] 视频转换流程结束")
    }
}

// MARK: - 格式转换设置视图
struct FormatSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: FormatSettings
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text("目标图片格式")
                        Spacer()
                        Picker("", selection: $settings.targetImageFormat) {
                            Text("JPEG").tag(ImageFormat.jpeg)
                            Text("PNG").tag(ImageFormat.png)
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("图片格式设置")
                }
                
                Section {
                    HStack {
                        Text("目标视频格式")
                        Spacer()
                        Picker("目标视频格式", selection: $settings.targetVideoFormat) {
                            Text("MP4").tag("mp4")
                            Text("MOV").tag("mov")
                            Text("M4V").tag("m4v")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("使用 HEVC (H.265) 编码", isOn: $settings.useHEVC)
                        
                        Text("HEVC 编码可以在保持相同质量的情况下减小文件大小，但兼容性可能不如 H.264")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality) ? 1 : 0.5)
                    .disabled(!AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality))
                } header: {
                    Text("视频格式设置")
                }
            }
            .navigationTitle("格式转换设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FormatView()
}
