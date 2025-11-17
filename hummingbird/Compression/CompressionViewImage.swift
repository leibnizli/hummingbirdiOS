//
//  CompressionView.swift
//  hummingbird
//
//  Compression View
//
import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import SDWebImage
import SDWebImageWebPCoder
import UniformTypeIdentifiers

struct CompressionViewImage: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isCompressing = false
    @State private var showingSettings = false
    @State private var showingFilePicker = false
    @State private var showingPhotoPicker = false
    @StateObject private var settings = CompressionSettings()
    
    // 检查是否有媒体项正在加载
    private var hasLoadingItems: Bool {
        mediaItems.contains { $0.status == .loading }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部选择按钮
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // 左侧：下拉菜单选择来源
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
                    .disabled(isCompressing || hasLoadingItems)
                    
                    // 右侧：开始按钮
                    Button(action: startBatchCompression) {
                        HStack(spacing: 6) {
                            if isCompressing || hasLoadingItems {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isCompressing ? "Processing" : hasLoadingItems ? "Loading" : "Start")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mediaItems.isEmpty || isCompressing || hasLoadingItems ? .gray : .green)
                    .disabled(mediaItems.isEmpty || isCompressing || hasLoadingItems)
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
                    Text("Select media to compress")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mediaItems) { item in
                        CompressionItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.visible)
                    }
                    .onDelete { indexSet in
                        // 只有在不压缩且没有加载项时才允许删除
                        guard !isCompressing && !hasLoadingItems else { return }
                        
                        // 检查是否删除了正在播放的音频
                        for index in indexSet {
                            let item = mediaItems[index]
                            if item.isAudio && AudioPlayerManager.shared.isCurrentAudio(itemId: item.id) {
                                AudioPlayerManager.shared.stop()
                            }
                        }
                        
                        withAnimation {
                            mediaItems.remove(atOffsets: indexSet)
                        }
                    }
                    .deleteDisabled(isCompressing || hasLoadingItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Image Compression")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
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
        .onChange(of: settings.preserveAnimatedAVIF) { _, newValue in
            Task { @MainActor in
                for item in mediaItems where item.isAnimatedAVIF {
                    item.infoMessage = avifAnimationMessage(preserve: newValue)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            CompressionSettingsViewImage(settings: settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.images]))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    await loadFileURLs(urls)
                } catch {
                    print("File selection error: \(error.localizedDescription)")
                }
            }
        }
    }
    //MARK: 选择文件 icloud
    private func loadFileURLs(_ urls: [URL]) async {
        // 停止当前播放
        await MainActor.run {
            AudioPlayerManager.shared.stop()
        }
        
        // 清空之前的列表
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for url in urls {
            // 验证文件是否可访问
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 检查文件类型
            let fileExtension = url.pathExtension.lowercased()
            let audioExtensions = ["mp3", "m4a", "aac", "wav", "flac", "ogg"]
            let isAudio = audioExtensions.contains(fileExtension)
            let isVideo = !isAudio && (UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) ?? false)
            let mediaItem = MediaItem(pickerItem: nil, isVideo: isVideo)
            
            // 添加到列表
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            do {
                // 读取文件数据
                let data = try Data(contentsOf: url)
                
                // 检测是否是 WebP/AVIF
                let isWebP = UTType(filenameExtension: url.pathExtension)?.conforms(to: .webP) ?? false
                let isAnimatedAVIF = MediaCompressor.isAnimatedAVIF(data: data)
                
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    mediaItem.isAnimatedAVIF = isAnimatedAVIF
                    
                    // 使用 UTType 获取更准确的扩展名
                    if let type = UTType(filenameExtension: url.pathExtension) {
                        let normalizedExtension = type.preferredFilenameExtension?.lowercased() ?? fileExtension
                        mediaItem.fileExtension = normalizedExtension
                        
                        // 设置格式
                        if isVideo {
                            mediaItem.outputVideoFormat = normalizedExtension
                        } else {
                            if type.conforms(to: .png) {
                                mediaItem.originalImageFormat = .png
                            } else if type.conforms(to: .heic) {
                                mediaItem.originalImageFormat = .heic
                            } else if type.conforms(to: .webP) {
                                mediaItem.originalImageFormat = .webp
                            } else if let avifType = UTType(filenameExtension: "avif"), type.conforms(to: avifType) {
                                mediaItem.originalImageFormat = .avif
                                mediaItem.fileExtension = "avif"
                            } else {
                                mediaItem.originalImageFormat = .jpeg
                            }
                        }
                    } else {
                        // 回退到文件扩展名
                        mediaItem.fileExtension = fileExtension
                        if isVideo {
                            mediaItem.outputVideoFormat = fileExtension
                        } else {
                            switch fileExtension {
                            case "png":
                                mediaItem.originalImageFormat = .png
                            case "heic", "heif":
                                mediaItem.originalImageFormat = .heic
                            case "webp":
                                mediaItem.originalImageFormat = .webp
                            case "avif":
                                mediaItem.originalImageFormat = .avif
                            default:
                                mediaItem.originalImageFormat = .jpeg
                            }
                        }
                    }
                    
                    // 如果是图片，生成缩略图和获取分辨率
                    if !isVideo && !isAudio, let image = UIImage(data: data) {
                        mediaItem.thumbnailImage = generateThumbnail(from: image)
                        mediaItem.originalResolution = image.size
                        mediaItem.status = .pending
                        if isAnimatedAVIF {
                            mediaItem.infoMessage = settings.preserveAnimatedAVIF ? "Animated AVIF detected — will preserve frames" : "Animated AVIF detected — will convert to static"
                        }
                    }
                }
                
                // 检测动画 WebP（文件选择器路径）
                if isWebP && !isVideo && !isAudio {
                    print("🟡 [LoadFileURLs] 检测到 WebP 文件，开始检测动画")
                    
                    // 快速文件头检测
                    let bytes = [UInt8](data.prefix(30))
                    var hasAnimationFlag = false
                    
                    if bytes.count >= 21 &&
                        bytes[12] == 0x56 && bytes[13] == 0x50 &&
                        bytes[14] == 0x38 && bytes[15] == 0x58 {
                        let flags = bytes[20]
                        hasAnimationFlag = (flags & 0x02) != 0
                        print("📊 [LoadFileURLs] 文件头检测 - VP8X 标志位: 0x\(String(format: "%02X", flags)), 动画: \(hasAnimationFlag)")
                    }
                    
                    // 如果有动画标志，立即设置
                    if hasAnimationFlag {
                        await MainActor.run {
                            mediaItem.isAnimatedWebP = true
                            mediaItem.webpFrameCount = 0
                        }
                    }
                    
                    // 后台获取准确帧数
                    Task {
                        if let animatedImage = SDAnimatedImage(data: data) {
                            let count = animatedImage.animatedImageFrameCount
                            let isAnimated = count > 1
                            let frameCount = Int(count)
                            
                            print("📊 [LoadFileURLs] SDAnimatedImage 检测完成 - 动画: \(isAnimated), 帧数: \(frameCount)")
                            
                            await MainActor.run {
                                mediaItem.isAnimatedWebP = isAnimated
                                mediaItem.webpFrameCount = frameCount
                            }
                        }
                    }
                }
                
                if isAnimatedAVIF {
                    print("🎬 [LoadFileURLs] 检测到动画 AVIF，将在压缩时保留动画")
                    Task {
                        let frames = await AVIFCompressor.detectFrameCount(avifData: data)
                        await MainActor.run {
                            mediaItem.avifFrameCount = frames
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    //从相册选择
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        print("🟢 [LoadSelectedItems] 开始加载 \(items.count) 个文件")
        
        // 停止当前播放
        await MainActor.run {
            AudioPlayerManager.shared.stop()
        }
        
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for (index, item) in items.enumerated() {
            print("🟢 [LoadSelectedItems] 处理第 \(index + 1)/\(items.count) 个文件")
            print("🟢 [LoadSelectedItems] 支持的类型: \(item.supportedContentTypes.map { $0.identifier })")
            
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
            let mediaItem = MediaItem(pickerItem: item, isVideo: isVideo)
            
            print("🟢 [LoadSelectedItems] 文件类型: \(isVideo ? "视频" : "图片")")
            
            // 先添加到列表，显示加载状态
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            // 图片：正常加载
            print("🟢 [LoadSelectedItems] 调用 loadImageItem")
            await loadImageItem(item, mediaItem)
        }
        
        print("🟢 [LoadSelectedItems] 所有文件加载完成")
    }
    
    private func loadImageItem(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        print("🔵 [LoadImage] 开始加载图片")
        
        if let data = try? await item.loadTransferable(type: Data.self) {
            print("🔵 [LoadImage] 数据加载成功，大小: \(data.count) bytes")
            
            // 检测原始图片格式
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
            let avifType = UTType(filenameExtension: "avif")
            let isWebP = item.supportedContentTypes.contains { contentType in
                contentType.identifier == "org.webmproject.webp" ||
                contentType.preferredMIMEType == "image/webp"
            }
            let isAVIF = item.supportedContentTypes.contains { contentType in
                if contentType.identifier == "public.avif" ||
                    contentType.identifier == "public.avci" ||
                    contentType.preferredMIMEType == "image/avif" {
                    return true
                }
                if let avifType = avifType {
                    return contentType.conforms(to: avifType)
                }
                return false
            }
            let isAnimatedAVIF = MediaCompressor.isAnimatedAVIF(data: data)
            
            // 先设置基本信息
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
                mediaItem.isAnimatedAVIF = isAnimatedAVIF
                
                if isPNG {
                    mediaItem.originalImageFormat = .png
                    mediaItem.fileExtension = "png"
                } else if isHEIC {
                    mediaItem.originalImageFormat = .heic
                    mediaItem.fileExtension = "heic"
                } else if isWebP {
                    mediaItem.originalImageFormat = .webp
                    mediaItem.fileExtension = "webp"
                } else if isAVIF {
                    mediaItem.originalImageFormat = .avif
                    mediaItem.fileExtension = "avif"
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
                if isAnimatedAVIF {
                    mediaItem.infoMessage = avifAnimationMessage(preserve: settings.preserveAnimatedAVIF)
                }
            }
            // 异步检测动画 WebP（不阻塞 UI）
            if isWebP {
                // 先快速检查文件头
                let bytes = [UInt8](data.prefix(30))
                var hasAnimationFlag = false
                
                if bytes.count >= 21 &&
                    bytes[12] == 0x56 && bytes[13] == 0x50 &&
                    bytes[14] == 0x38 && bytes[15] == 0x58 {
                    let flags = bytes[20]
                    hasAnimationFlag = (flags & 0x02) != 0
                    print("📊 [LoadImage] 文件头快速检测 - VP8X 标志位: 0x\(String(format: "%02X", flags)), 动画标志: \(hasAnimationFlag)")
                }
                
                // 如果文件头显示有动画，先设置标识
                if hasAnimationFlag {
                    await MainActor.run {
                        mediaItem.isAnimatedWebP = true
                        mediaItem.webpFrameCount = 0  // 暂时未知
                    }
                }
                
                // 然后在后台获取准确帧数
                Task {
                    let startTime = Date()
                    print("🔍 [LoadImage] 开始后台检测准确帧数，文件大小: \(data.count) bytes")
                    
                    if let animatedImage = SDAnimatedImage(data: data) {
                        let count = animatedImage.animatedImageFrameCount
                        let isAnimated = count > 1
                        let frameCount = Int(count)
                        
                        let elapsed = Date().timeIntervalSince(startTime)
                        print("📊 [LoadImage] SDAnimatedImage 检测完成 (\(String(format: "%.2f", elapsed))s) - 动画: \(isAnimated), 帧数: \(frameCount)")
                        
                        await MainActor.run {
                            mediaItem.isAnimatedWebP = isAnimated
                            mediaItem.webpFrameCount = frameCount
                        }
                    } else {
                        print("⚠️ [LoadImage] SDAnimatedImage 初始化失败，保持文件头检测结果")
                    }
                }
            }
            if isAnimatedAVIF {
                Task {
                    let frames = await AVIFCompressor.detectFrameCount(avifData: data)
                    await MainActor.run {
                        mediaItem.avifFrameCount = frames
                    }
                }
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
    
    private func startBatchCompression() {
        
        Task {
            // 立即在主线程更新状态
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompressing = true
                }
            }
            
            // 给 UI 一点时间渲染
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15秒
            
            // 重置所有项目状态，以便重新压缩
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedResolution = nil
                    item.compressedVideoURL = nil
                    item.errorMessage = nil
                    item.preservedAnimation = false
                }
            }
            
            for item in mediaItems {
                await compressItem(item)
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompressing = false
                }
            }
        }
    }
    
    private func compressItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .compressing
            item.progress = 0
        }
        
        await compressImage(item)
    }
    
    private func compressImage(_ item: MediaItem) async {
        guard let originalData = item.originalData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "Unable to load original image"
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
            } else if item.originalImageFormat == .avif {
                // AVIF 始终保持 AVIF 格式
                outputFormat = .avif
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
            
            // 检测是否是动画 WebP
            if outputFormat == .webp {
                let webpCoder = SDImageWebPCoder.shared
                if let animatedImage = SDAnimatedImage(data: originalData) {
                    let frameCount = animatedImage.animatedImageFrameCount
                    await MainActor.run {
                        item.isAnimatedWebP = frameCount > 1
                        item.webpFrameCount = Int(frameCount)
                    }
                    print("📊 [CompressionView] 检测到 WebP - 动画: \(frameCount > 1), 帧数: \(frameCount)")
                }
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
                item.infoMessage = nil
                if compressed.count >= originalData.count {
                    print("⚠️ [Compression Check] Compressed size (\(compressed.count) bytes) >= Original size (\(originalData.count) bytes), keeping original")
                    item.compressedData = originalData
                    item.compressedSize = originalData.count
                    item.outputImageFormat = item.originalImageFormat  // 保持原格式
                    
                    // 如果是动画 WebP，保留原始动画
                    if item.isAnimatedWebP {
                        item.preservedAnimation = true
                    }
                    if item.isAnimatedAVIF {
                        item.preservedAnimation = true
                        item.infoMessage = "Animated AVIF preserved (no size reduction)"
                    }
                } else {
                    print("✅ [Compression Check] Compression successful, reduced from \(originalData.count) bytes to \(compressed.count) bytes")
                    item.compressedData = compressed
                    item.compressedSize = compressed.count
                    item.outputImageFormat = outputFormat  // 使用压缩后的格式
                    
                    // 验证压缩后是否保留了动画
                    if item.isAnimatedWebP && outputFormat == .webp {
                        if let compressedAnimated = SDAnimatedImage(data: compressed) {
                            let compressedFrameCount = compressedAnimated.animatedImageFrameCount
                            item.preservedAnimation = compressedFrameCount > 1
                            item.webpFrameCount = Int(compressedFrameCount)
                            print("📊 [CompressionView] 压缩后 WebP - 帧数: \(compressedFrameCount), 保留动画: \(item.preservedAnimation)")
                        } else {
                            // 无法解析压缩结果时，根据设置回退
                            item.preservedAnimation = settings.preserveAnimatedWebP
                            if !settings.preserveAnimatedWebP {
                                item.webpFrameCount = 1
                            }
                        }
                    }
                    if item.isAnimatedAVIF {
                        let preserved = MediaCompressor.isAnimatedAVIF(data: compressed)
                        item.preservedAnimation = preserved
                        if preserved {
                            item.infoMessage = "Animated AVIF re-encoded with quality settings"
                        } else {
                            item.infoMessage = "Animation removed during AVIF re-encode"
                        }
                    }
                    if !item.isAnimatedAVIF && !item.isAnimatedWebP {
                        item.infoMessage = nil
                    }
                }
                
                // 记录 PNG 压缩参数
                if outputFormat == .png, let report = MediaCompressor.lastPNGCompressionReport {
                    item.pngCompressionReport = report
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
    
    private func avifAnimationMessage(preserve: Bool) -> String {
        preserve ? "Animated AVIF detected — will preserve frames" : "Animated AVIF detected — will convert to static"
    }
}

#Preview {
    CompressionViewImage()
}
