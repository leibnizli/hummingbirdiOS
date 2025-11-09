//
//  ResolutionView.swift
//  hummingbird
//
//  修改分辨率视图
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import SDWebImageWebPCoder

extension NumberFormatter {
    static var noGrouping: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter
    }
}

struct ResolutionView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isProcessing = false
    @State private var showingFilePicker = false
    @State private var showingPhotoPicker = false
    @State private var showingSettings = false
    @State private var targetResolution: ImageResolution = .wallpaperHD
    @State private var customWidth: Int = 1920
    @State private var customHeight: Int = 1080
    @State private var resizeMode: ResizeMode = .cover
    
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
                        Button(action: startBatchResize) {
                            HStack(spacing: 6) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                Text(isProcessing ? "处理中" : "开始调整")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(mediaItems.isEmpty || isProcessing ? .gray : .orange)
                        .disabled(mediaItems.isEmpty || isProcessing)
                        .animation(.easeInOut(duration: 0.2), value: isProcessing)
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
                        Text("选择图片或视频调整分辨率")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(mediaItems) { item in
                            ResolutionItemRow(item: item)
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
            .navigationTitle("修改分辨率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ResolutionSettingsSheet(
                    targetResolution: $targetResolution,
                    customWidth: $customWidth,
                    customHeight: $customHeight,
                    resizeMode: $resizeMode
                )
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
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie],
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    await loadFileURLs(urls)
                } catch {
                    print("文件选择错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 从文件选择器加载文件（iCloud）
    private func loadFileURLs(_ urls: [URL]) async {
        // 清空之前的列表
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
                    
                    // 使用 UTType 获取更准确的扩展名
                    if let type = UTType(filenameExtension: url.pathExtension) {
                        mediaItem.fileExtension = type.preferredFilenameExtension?.lowercased() ?? url.pathExtension.lowercased()
                        
                        // 设置格式
                        if isVideo {
                            mediaItem.outputVideoFormat = type.preferredFilenameExtension?.lowercased() ?? url.pathExtension.lowercased()
                        } else {
                            if type.conforms(to: .png) {
                                mediaItem.originalImageFormat = .png
                            } else if type.conforms(to: .heic) {
                                mediaItem.originalImageFormat = .heic
                            } else if type.conforms(to: .webP) {
                                mediaItem.originalImageFormat = .webp
                            } else {
                                mediaItem.originalImageFormat = .jpeg
                            }
                        }
                    } else {
                        // 回退到文件扩展名
                        mediaItem.fileExtension = url.pathExtension.lowercased()
                        if isVideo {
                            mediaItem.outputVideoFormat = url.pathExtension.lowercased()
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
                if isVideo {
                    // 创建临时文件，使用检测到的扩展名
                    let detectedExtension = mediaItem.fileExtension ?? url.pathExtension
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                        .appendingPathExtension(detectedExtension)
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        mediaItem.sourceVideoURL = tempURL
                    }
                    
                    // 加载视频元数据
                    await loadVideoMetadata(for: mediaItem, url: tempURL)
                }
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // 从相册选择
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
                // 视频优化：延迟加载，只在需要时加载完整数据
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
                
                // 检测原始图片格式（与 CompressionView 保持一致）
                var detectedImageFormat: ImageFormat = .jpeg
                var detectedExtension = "jpg"
                
                for contentType in item.supportedContentTypes {
                    if contentType.identifier == "public.png" ||
                       contentType.conforms(to: .png) {
                        detectedImageFormat = .png
                        detectedExtension = "png"
                        break
                    } else if contentType.identifier == "public.heic" || 
                              contentType.identifier == "public.heif" ||
                              contentType.conforms(to: .heic) ||
                              contentType.conforms(to: .heif) {
                        detectedImageFormat = .heic
                        detectedExtension = "heic"
                        break
                    } else if contentType.identifier == "org.webmproject.webp" ||
                              contentType.preferredMIMEType == "image/webp" {
                        detectedImageFormat = .webp
                        detectedExtension = "webp"
                        break
                    } else if contentType.conforms(to: .jpeg) {
                        detectedImageFormat = .jpeg
                        detectedExtension = "jpg"
                        break
                    }
                }
                
                mediaItem.originalImageFormat = detectedImageFormat
                mediaItem.fileExtension = detectedExtension
                
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
        // 检测视频格式（与 CompressionView 保持一致）
        var detectedFormat = "video"
        
        // 检查所有支持的内容类型
        for contentType in item.supportedContentTypes {
            // M4V 格式检测（优先检测，因为 m4v 也可能匹配 mpeg4Movie）
            if contentType.identifier == "public.m4v" ||
               contentType.preferredFilenameExtension == "m4v" {
                detectedFormat = "m4v"
                break
            }
            // MOV 格式检测
            else if contentType.identifier == "com.apple.quicktime-movie" ||
                    contentType.conforms(to: .quickTimeMovie) ||
                    contentType.preferredFilenameExtension == "mov" {
                detectedFormat = "mov"
                break
            }
            // MP4 格式检测
            else if contentType.identifier == "public.mpeg-4" ||
                    contentType.conforms(to: .mpeg4Movie) ||
                    contentType.preferredFilenameExtension == "mp4" ||
                    contentType.identifier == "public.mp4" {
                detectedFormat = "mp4"
                break
            }
            // AVI 格式检测
            else if contentType.identifier == "public.avi" ||
                    contentType.preferredFilenameExtension == "avi" {
                detectedFormat = "avi"
                break
            }
            // MKV 格式检测
            else if contentType.identifier == "org.matroska.mkv" ||
                    contentType.preferredFilenameExtension == "mkv" {
                detectedFormat = "mkv"
                break
            }
            // WebM 格式检测
            else if contentType.identifier == "org.webmproject.webm" ||
                    contentType.preferredFilenameExtension == "webm" {
                detectedFormat = "webm"
                break
            }
            // 通用视频格式检测
            else if contentType.conforms(to: .movie) ||
                    contentType.conforms(to: .video) {
                // 尝试从 preferredFilenameExtension 获取具体格式
                if let ext = contentType.preferredFilenameExtension?.lowercased(),
                   ["mov", "mp4", "avi", "mkv", "webm", "m4v"].contains(ext) {
                    detectedFormat = ext
                    break
                }
            }
        }
        
        await MainActor.run {
            mediaItem.fileExtension = detectedFormat
            if detectedFormat != "video" {
                mediaItem.outputVideoFormat = detectedFormat
            }
        }
        
        // 优化：使用 URL 方式加载视频，避免将整个文件加载到内存
        if let url = try? await item.loadTransferable(type: URL.self) {
            await MainActor.run {
                mediaItem.sourceVideoURL = url
                
                // 快速获取文件大小（不加载整个文件）
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
                    mediaItem.originalSize = fileSize
                }
                
                // 异步获取视频信息和缩略图
                Task {
                    await loadVideoMetadata(for: mediaItem, url: url)
                }
            }
        } else {
            // 回退到数据加载方式（兼容性）
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                        .appendingPathExtension("mov")
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
    
    private func startBatchResize() {
        isProcessing = true
        
        Task {
            // 重置所有项目状态，以便重新处理
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedResolution = nil
                    item.compressedVideoURL = nil
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await resizeItem(item)
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func resizeItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        
        if item.isVideo {
            await resizeVideo(item)
        } else {
            await resizeImage(item)
        }
    }
    
    private func resizeImage(_ item: MediaItem) async {
        guard let originalData = item.originalData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        
        guard var image = UIImage(data: originalData) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法解码图片"
            }
            return
        }
        
        // 使用原始格式（从 item 中获取）
        let originalFormat = item.originalImageFormat ?? .jpeg
        
        // 修正方向
        image = image.fixOrientation()
        
        // 获取目标尺寸并进行智能裁剪和缩放
        if let (width, height) = getTargetSize() {
            image = resizeAndCropImage(image, targetWidth: width, targetHeight: height, mode: resizeMode)
        }
        
        // 使用系统原生编码（不调用压缩），保持高质量
        let resizedData: Data
        switch originalFormat {
        case .png:
            // PNG 格式 - 无损压缩
            guard let pngData = image.pngData() else {
                await MainActor.run {
                    item.status = .failed
                    item.errorMessage = "无法编码 PNG 图片"
                }
                return
            }
            resizedData = pngData
            print("✅ [分辨率调整] PNG 编码成功 - 大小: \(resizedData.count) bytes")
            
        case .heic:
            // HEIC 格式
            if #available(iOS 11.0, *) {
                let mutableData = NSMutableData()
                if let cgImage = image.cgImage,
                   let destination = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil) {
                    let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        resizedData = mutableData as Data
                        print("✅ [分辨率调整] HEIC 编码成功 - 大小: \(resizedData.count) bytes")
                    } else {
                        await MainActor.run {
                            item.status = .failed
                            item.errorMessage = "HEIC 编码失败"
                        }
                        return
                    }
                } else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法创建 HEIC 编码器"
                    }
                    return
                }
            } else {
                // iOS 11 以下不支持 HEIC，回退到 JPEG
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法编码图片"
                    }
                    return
                }
                resizedData = jpegData
                print("✅ [分辨率调整] JPEG 编码成功（HEIC 不支持） - 大小: \(resizedData.count) bytes")
            }
            
        case .jpeg:
            // JPEG 格式 - 使用系统原生编码
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                await MainActor.run {
                    item.status = .failed
                    item.errorMessage = "无法编码图片"
                }
                return
            }
            resizedData = jpegData
            print("✅ [分辨率调整] JPEG 编码成功 - 大小: \(resizedData.count) bytes")
            
        case .webp:
            // WebP 格式 - 使用 SDWebImageWebPCoder
            let webpCoder = SDImageWebPCoder.shared
            if let webpData = webpCoder.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: 0.9]) {
                resizedData = webpData
                print("✅ [分辨率调整] WebP 编码成功 - 大小: \(resizedData.count) bytes")
            } else {
                // WebP 编码失败，回退到 JPEG
                print("⚠️ [分辨率调整] WebP 编码失败，回退到 JPEG")
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法编码图片"
                    }
                    return
                }
                resizedData = jpegData
                print("✅ [分辨率调整] JPEG 编码成功（WebP 回退） - 大小: \(resizedData.count) bytes")
            }
        }
        
        await MainActor.run {
            item.compressedData = resizedData
            item.compressedSize = resizedData.count
            item.compressedResolution = image.size
            item.outputImageFormat = originalFormat  // 记录输出格式
            item.status = .completed
            item.progress = 1.0
        }
    }
    
    // 智能缩放和裁剪图片到目标尺寸
    private func resizeAndCropImage(_ image: UIImage, targetWidth: Int, targetHeight: Int, mode: ResizeMode) -> UIImage {
        let originalSize = image.size
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        // 计算目标宽高比和原始宽高比
        let targetAspectRatio = CGFloat(targetWidth) / CGFloat(targetHeight)
        let originalAspectRatio = originalSize.width / originalSize.height
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        switch mode {
        case .cover:
            // Cover 模式：等比例缩放填充，裁剪超出部分
            // 计算缩放比例，使用较大的比例以确保填满目标尺寸
            let scale: CGFloat
            if originalAspectRatio > targetAspectRatio {
                // 原图更宽，以高度为准缩放
                scale = targetSize.height / originalSize.height
            } else {
                // 原图更高或相同，以宽度为准缩放
                scale = targetSize.width / originalSize.width
            }
            
            // 缩放后的尺寸
            let scaledSize = CGSize(
                width: originalSize.width * scale,
                height: originalSize.height * scale
            )
            
            // 计算裁剪区域（居中裁剪）
            let cropRect = CGRect(
                x: (scaledSize.width - targetSize.width) / 2,
                y: (scaledSize.height - targetSize.height) / 2,
                width: targetSize.width,
                height: targetSize.height
            )
            
            // 先缩放到合适大小
            let scaledRenderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
            let scaledImage = scaledRenderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
            
            // 然后裁剪到目标尺寸
            let cropRenderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return cropRenderer.image { _ in
                scaledImage.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
            }
            
        case .fit:
            // Fit 模式：按原比例缩放适应目标尺寸，保持完整内容
            // 计算缩放比例，使用较小的比例以确保完整显示
            let scale: CGFloat
            if originalAspectRatio > targetAspectRatio {
                // 原图更宽，以宽度为准缩放
                scale = targetSize.width / originalSize.width
            } else {
                // 原图更高或相同，以高度为准缩放
                scale = targetSize.height / originalSize.height
            }
            
            // 缩放后的实际尺寸
            let scaledSize = CGSize(
                width: originalSize.width * scale,
                height: originalSize.height * scale
            )
            
            // 计算居中位置
            let x = (targetSize.width - scaledSize.width) / 2
            let y = (targetSize.height - scaledSize.height) / 2
            
            // 创建目标尺寸的画布，居中绘制缩放后的图片
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            return renderer.image { context in
                // 填充透明背景（如果需要）
                // UIColor.clear.setFill()
                // context.fill(CGRect(origin: .zero, size: targetSize))
                
                // 居中绘制图片
                image.draw(in: CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height))
            }
        }
    }
    
    private func resizeVideo(_ item: MediaItem) async {
        // 确保有视频 URL
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        
        // 如果需要完整数据但还没有加载，现在加载
        if item.originalData == nil {
            await item.loadVideoDataIfNeeded()
        }
        
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法创建导出会话"
            }
            return
        }
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("resized_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 设置视频分辨率
        if let (width, height) = getTargetSize() {
            let size = CGSize(width: width, height: height)
            exportSession.videoComposition = createVideoComposition(asset: asset, targetSize: size, mode: resizeMode)
        }
        
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
                
                item.status = .completed
                item.progress = 1.0
            default:
                item.status = .failed
                item.errorMessage = exportSession.error?.localizedDescription ?? "导出失败"
            }
        }
    }
    
    // 创建视频合成，实现智能缩放和裁剪
    private func createVideoComposition(asset: AVAsset, targetSize: CGSize, mode: ResizeMode) -> AVMutableVideoComposition {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return AVMutableVideoComposition()
        }
        
        let composition = AVMutableVideoComposition()
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // 获取视频原始尺寸和方向
        let videoSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
        let actualSize = isPortrait ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
        
        // 计算宽高比
        let targetAspectRatio = targetSize.width / targetSize.height
        let videoAspectRatio = actualSize.width / actualSize.height
        
        // 根据模式计算缩放比例和最终输出尺寸
        let scale: CGFloat
        let finalRenderSize: CGSize
        let tx: CGFloat
        let ty: CGFloat
        
        switch mode {
        case .cover:
            // Cover 模式：使用较大的缩放比例以填满目标尺寸（会裁剪超出部分）
            if videoAspectRatio > targetAspectRatio {
                // 视频更宽，以高度为准
                scale = targetSize.height / actualSize.height
            } else {
                // 视频更高，以宽度为准
                scale = targetSize.width / actualSize.width
            }
            
            // Cover 模式输出目标尺寸
            finalRenderSize = targetSize
            
            // 计算缩放后的尺寸
            let scaledSize = CGSize(width: actualSize.width * scale, height: actualSize.height * scale)
            
            // 计算居中偏移
            tx = (targetSize.width - scaledSize.width) / 2
            ty = (targetSize.height - scaledSize.height) / 2
            
        case .fit:
            // Fit 模式：使用较小的缩放比例以保持完整内容
            if videoAspectRatio > targetAspectRatio {
                // 视频更宽，以宽度为准
                scale = targetSize.width / actualSize.width
            } else {
                // 视频更高，以高度为准
                scale = targetSize.height / actualSize.height
            }
            
            // Fit 模式输出实际缩放后的尺寸（不超过目标尺寸）
            let scaledSize = CGSize(width: actualSize.width * scale, height: actualSize.height * scale)
            finalRenderSize = scaledSize
            
            // Fit 模式不需要偏移，因为输出尺寸就是缩放后的尺寸
            tx = 0
            ty = 0
        }
        
        // 设置最终输出尺寸
        composition.renderSize = finalRenderSize
        
        // 构建变换矩阵
        var finalTransform = CGAffineTransform.identity
        
        // 先应用原始的旋转/翻转变换
        finalTransform = finalTransform.concatenating(transform)
        
        // 然后缩放
        finalTransform = finalTransform.scaledBy(x: scale, y: scale)
        
        // 最后平移到居中位置（仅 Cover 模式需要）
        if mode == .cover {
            if isPortrait {
                // 竖屏视频需要特殊处理偏移
                finalTransform = finalTransform.translatedBy(x: ty, y: tx)
            } else {
                finalTransform = finalTransform.translatedBy(x: tx, y: ty)
            }
        }
        
        transformer.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [transformer]
        composition.instructions = [instruction]
        
        return composition
    }
    
    private func getTargetSize() -> (Int, Int)? {
        if targetResolution == .custom {
            return (customWidth, customHeight)
        } else if let size = targetResolution.size {
            return (size.width, size.height)
        }
        return nil
    }
}

// MARK: - 分辨率设置 Sheet
struct ResolutionSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var targetResolution: ImageResolution
    @Binding var customWidth: Int
    @Binding var customHeight: Int
    @Binding var resizeMode: ResizeMode
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("目标分辨率", selection: $targetResolution) {
                        ForEach(ImageResolution.allCases) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if targetResolution == .custom {
                        HStack {
                            Text("宽度")
                                .frame(width: 50, alignment: .leading)
                            TextField("1920", value: $customWidth, formatter: NumberFormatter.noGrouping)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            Text("px")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("高度")
                                .frame(width: 50, alignment: .leading)
                            TextField("1080", value: $customHeight, formatter: NumberFormatter.noGrouping)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            Text("px")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("分辨率设置")
                }
                
                Section {
                    Picker("缩放模式", selection: $resizeMode) {
                        ForEach(ResizeMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(resizeMode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("缩放模式")
                }
            }
            .navigationTitle("分辨率设置")
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
    ResolutionView()
}
