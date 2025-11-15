//
//  CompressionView.swift
//  hummingbird
//
//  Compression View
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import SDWebImageWebPCoder

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
                
                // 检测是否是 WebP
                let isWebP = UTType(filenameExtension: url.pathExtension)?.conforms(to: .webP) ?? false
                
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
                    if !isVideo && !isAudio, let image = UIImage(data: data) {
                        mediaItem.thumbnailImage = generateThumbnail(from: image)
                        mediaItem.originalResolution = image.size
                        mediaItem.status = .pending
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
                
                // 如果是音频，处理音频相关信息
                if isAudio {
                    // 创建临时文件
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                        .appendingPathExtension(fileExtension)
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        mediaItem.sourceVideoURL = tempURL  // 复用这个字段存储音频URL
                    }
                    
                    // 加载音频元数据
                    await loadAudioMetadata(for: mediaItem, url: tempURL)
                }
                // 如果是视频，处理视频相关信息
                else if isVideo {
                    // 创建临时文件，使用检测到的扩展名
                    let detectedExtension = mediaItem.fileExtension ?? url.pathExtension
                    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                        .appendingPathExtension(detectedExtension)
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        mediaItem.sourceVideoURL = tempURL
                    }
                    
                    // 加载视频元数据（会进一步验证格式）
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
            
            if isVideo {
                // 视频优化：延迟加载，只在需要时加载完整数据
                print("🟢 [LoadSelectedItems] 调用 loadVideoItemOptimized")
                await loadVideoItemOptimized(item, mediaItem)
            } else {
                // 图片：正常加载
                print("🟢 [LoadSelectedItems] 调用 loadImageItem")
                await loadImageItem(item, mediaItem)
            }
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
            let isWebP = item.supportedContentTypes.contains { contentType in
                contentType.identifier == "org.webmproject.webp" ||
                contentType.preferredMIMEType == "image/webp"
            }
            
            // 先设置基本信息
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
                
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
        }
    }
    
    private func loadVideoItemOptimized(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        // 检测视频格式
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
            // 设置文件扩展名
            mediaItem.fileExtension = detectedFormat
            // 同时记录原始视频格式，用于后续格式转换的显示
            if detectedFormat != "video" {
                mediaItem.outputVideoFormat = detectedFormat
            }
        }
        
        // 先尝试使用 URL 方式加载（更高效）
        if let url = try? await item.loadTransferable(type: URL.self) {
            await MainActor.run {
                mediaItem.sourceVideoURL = url
                
                // 快速获取文件大小（不加载整个文件）
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
        } else if let data = try? await item.loadTransferable(type: Data.self) {
            // 如果 URL 方式失败，使用 Data 方式加载
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
            }
            
            // 创建临时文件
            let detectedExtension = mediaItem.fileExtension.isEmpty ? "mp4" : mediaItem.fileExtension
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                .appendingPathExtension(detectedExtension)
            
            do {
                try data.write(to: tempURL)
                
                await MainActor.run {
                    mediaItem.sourceVideoURL = tempURL
                    // 立即设置为 pending 状态
                    mediaItem.status = .pending
                    
                    // 在后台异步获取视频信息和缩略图
                    Task {
                        await loadVideoMetadata(for: mediaItem, url: tempURL)
                    }
                }
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = "Unable to create temporary video file: \(error.localizedDescription)"
                }
            }
        } else {
            // 如果两种方式都失败，标记为失败
            await MainActor.run {
                mediaItem.status = .failed
                mediaItem.errorMessage = "Unable to load video file"
            }
        }
    }
    
    private func loadAudioMetadata(for mediaItem: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        
        // 加载音频时长
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            await MainActor.run {
                mediaItem.duration = durationSeconds
            }
            
            // 加载音频轨道信息
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = tracks.first {
                // 获取音频格式描述
                let formatDescriptions = audioTrack.formatDescriptions as! [CMFormatDescription]
                if let formatDescription = formatDescriptions.first {
                    let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    
                    if let asbd = audioStreamBasicDescription {
                        let sampleRate = Int(asbd.pointee.mSampleRate)
                        let channels = Int(asbd.pointee.mChannelsPerFrame)
                        
                        await MainActor.run {
                            mediaItem.audioSampleRate = sampleRate
                            mediaItem.audioChannels = channels
                        }
                    }
                }
                
                // 尝试估算比特率
                if let estimatedBitrate = try? await audioTrack.load(.estimatedDataRate), estimatedBitrate > 0 {
                    let bitrateKbps = Int(estimatedBitrate / 1000)
                    await MainActor.run {
                        mediaItem.audioBitrate = bitrateKbps
                    }
                    print("✅ [Audio Metadata] AVFoundation 检测到比特率: \(bitrateKbps) kbps")
                } else {
                    // AVFoundation 检测失败，使用 FFmpeg 作为回退
                    print("⚠️ [Audio Metadata] AVFoundation 无法检测比特率，尝试使用 FFmpeg")
                    
                    if let ffmpegInfo = await FFmpegAudioProbe.probeAudioFile(at: url) {
                        await MainActor.run {
                            // 使用 FFmpeg 检测到的信息
                            if let bitrate = ffmpegInfo.bitrate {
                                mediaItem.audioBitrate = bitrate
                                print("✅ [Audio Metadata] FFmpeg 检测到比特率: \(bitrate) kbps")
                            }
                            
                            // 如果 AVFoundation 没有检测到采样率和声道，也使用 FFmpeg 的
                            if mediaItem.audioSampleRate == nil, let sampleRate = ffmpegInfo.sampleRate {
                                mediaItem.audioSampleRate = sampleRate
                            }
                            if mediaItem.audioChannels == nil, let channels = ffmpegInfo.channels {
                                mediaItem.audioChannels = channels
                            }
                        }
                    } else {
                        // FFmpeg 也失败，尝试计算平均比特率
                        print("⚠️ [Audio Metadata] FFmpeg 探测失败，尝试计算平均比特率")
                        if let calculatedBitrate = FFmpegAudioProbe.calculateAverageBitrate(fileURL: url, duration: durationSeconds) {
                            await MainActor.run {
                                mediaItem.audioBitrate = calculatedBitrate
                                print("✅ [Audio Metadata] 计算得到平均比特率: \(calculatedBitrate) kbps")
                            }
                        } else {
                            print("❌ [Audio Metadata] 所有方法都无法检测比特率")
                        }
                    }
                }
            }
            
            // 设置状态为等待
            await MainActor.run {
                mediaItem.status = .pending
            }
        } catch {
            print("Failed to load audio metadata: \(error)")
            await MainActor.run {
                mediaItem.status = .failed
                mediaItem.errorMessage = "Failed to load audio metadata"
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
                
                // 获取帧率
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                
                await MainActor.run {
                    mediaItem.originalResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                    mediaItem.frameRate = Double(nominalFrameRate)
                }
            }
            
            // 加载视频时长
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            await MainActor.run {
                mediaItem.duration = durationSeconds
            }
        } catch {
            print("Failed to load video track info: \(error)")
        }
        
        // 检测视频编码（使用异步版本更可靠）
        if let codec = await MediaItem.detectVideoCodecAsync(from: url) {
            await MainActor.run {
                mediaItem.videoCodec = codec
            }
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
            print("Failed to generate video thumbnail: \(error)")
            // 设置默认视频图标
            await MainActor.run {
                item.thumbnailImage = UIImage(systemName: "video.fill")
            }
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
        
        if item.isAudio {
            await compressAudio(item)
        } else if item.isVideo {
            await compressVideo(item)
        } else {
            await compressImage(item)
        }
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
                if compressed.count >= originalData.count {
                    print("⚠️ [Compression Check] Compressed size (\(compressed.count) bytes) >= Original size (\(originalData.count) bytes), keeping original")
                    item.compressedData = originalData
                    item.compressedSize = originalData.count
                    item.outputImageFormat = item.originalImageFormat  // 保持原格式
                    
                    // 如果是动画 WebP，保留原始动画
                    if item.isAnimatedWebP {
                        item.preservedAnimation = true
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
                            print("📊 [CompressionView] 压缩后 WebP - 帧数: \(compressedFrameCount), 保留动画: \(item.preservedAnimation)")
                        }
                    }
                }
                
                // 记录 PNG 压缩参数
                if outputFormat == .png, let params = MediaCompressor.lastPNGCompressionParams {
                    item.pngCompressionParams = params
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
    
    private func compressAudio(_ item: MediaItem) async {
        // 确保有音频 URL
        guard let sourceURL = item.sourceVideoURL else {  // 复用这个字段
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "Unable to load original audio"
            }
            return
        }
        
        // 确定输出格式：如果选择"原始"，使用源文件格式
        let outputFormat: AudioFormat
        if settings.audioFormat == .original {
            // 根据文件扩展名确定格式
            let ext = item.fileExtension.lowercased()
            switch ext {
            case "mp3": outputFormat = .mp3
            case "aac": outputFormat = .aac
            case "m4a": outputFormat = .m4a
            case "opus": outputFormat = .opus
            case "flac": outputFormat = .flac
            case "wav": outputFormat = .wav
            default: outputFormat = .mp3  // 默认使用 MP3
            }
        } else {
            outputFormat = settings.audioFormat
        }
        
        // 使用 continuation 等待压缩完成
        await withCheckedContinuation { continuation in
            MediaCompressor.compressAudio(
                at: sourceURL,
                settings: settings,
                outputFormat: outputFormat,
                originalBitrate: item.audioBitrate,
                originalSampleRate: item.audioSampleRate,
                originalChannels: item.audioChannels,
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
                            
                            // 检查是否是格式转换（而非压缩）
                            // 如果选择了"原始"格式，则不是格式转换
                            let isFormatConversion = self.settings.audioFormat != .original && outputFormat.fileExtension != item.fileExtension.lowercased()
                            
                            // 如果是格式转换，即使文件变大也使用转换后的文件
                            // 如果是压缩（相同格式），且文件变大，则保留原始文件
                            if !isFormatConversion && compressedSize >= item.originalSize {
                                print("⚠️ [Audio Compression Check] Compressed size (\(compressedSize) bytes) >= Original size (\(item.originalSize) bytes), keeping original")
                                
                                item.compressedVideoURL = sourceURL  // 复用这个字段
                                item.compressedSize = item.originalSize
                                item.compressedAudioBitrate = item.audioBitrate
                                item.compressedAudioSampleRate = item.audioSampleRate
                                item.compressedAudioChannels = item.audioChannels
                                // 保持原格式
                                item.outputAudioFormat = nil
                                
                                // 清理压缩后的临时文件
                                try? FileManager.default.removeItem(at: url)
                            } else {
                                if isFormatConversion && compressedSize >= item.originalSize {
                                    print("ℹ️ [Audio Format Conversion] Format changed from \(item.fileExtension) to \(self.settings.audioFormat.fileExtension), size increased from \(item.originalSize) bytes to \(compressedSize) bytes")
                                } else {
                                    print("✅ [Audio Compression Check] Compression successful, reduced from \(item.originalSize) bytes to \(compressedSize) bytes")
                                }
                                
                                item.compressedVideoURL = url  // 复用这个字段
                                item.compressedSize = compressedSize
                                item.outputAudioFormat = outputFormat
                                
                                // 获取压缩后的音频信息（在设置完成状态之前）
                                let asset = AVURLAsset(url: url)
                                do {
                                    let tracks = try await asset.loadTracks(withMediaType: .audio)
                                    if let audioTrack = tracks.first {
                                        let formatDescriptions = audioTrack.formatDescriptions as! [CMFormatDescription]
                                        if let formatDescription = formatDescriptions.first {
                                            let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                                            
                                            if let asbd = audioStreamBasicDescription {
                                                let sampleRate = Int(asbd.pointee.mSampleRate)
                                                let channels = Int(asbd.pointee.mChannelsPerFrame)
                                                
                                                item.compressedAudioSampleRate = sampleRate
                                                item.compressedAudioChannels = channels
                                            }
                                        }
                                        
                                        if let estimatedBitrate = try? await audioTrack.load(.estimatedDataRate) {
                                            let bitrateKbps = Int(estimatedBitrate / 1000)
                                            item.compressedAudioBitrate = bitrateKbps
                                        }
                                    }
                                } catch {
                                    print("Failed to load compressed audio info: \(error)")
                                }
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
        }
    }
    
    private func compressVideo(_ item: MediaItem) async {
        // 确保有视频 URL
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "Unable to load original video"
            }
            return
        }
        
        // 如果需要完整数据但还没有加载，现在加载
        if item.originalData == nil {
            await item.loadVideoDataIfNeeded()
        }
        
        // 根据用户或检测到的期望输出格式选择容器类型（默认为 mp4）
        let desiredOutputFileType: AVFileType = {
            if let fmt = item.outputVideoFormat?.lowercased() {
                switch fmt {
                case "mov": return .mov
                case "m4v": return .m4v
                default: return .mp4
                }
            }
            return .mp4
        }()

        // 使用 continuation 等待压缩完成
        await withCheckedContinuation { continuation in
            MediaCompressor.compressVideo(
                at: sourceURL,
                settings: settings,
                outputFileType: desiredOutputFileType,
                originalFrameRate: item.frameRate,
                originalResolution: item.originalResolution,
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
                        // 智能判断：如果压缩后反而变大，可能选择保留「原始内容」但仍应满足用户期望的容器（例如用户希望 mp4）
                        if compressedSize >= item.originalSize {
                            print("⚠️ [Video Compression Check] Compressed size (\(compressedSize) bytes) >= Original size (\(item.originalSize) bytes), attempting to keep original stream but convert container to match desired format")

                            // 如果原文件扩展名与期望容器不同，尝试无损 remux（-c copy）到期望容器
                            let desiredExt: String = {
                                switch desiredOutputFileType {
                                case .mov: return "mov"
                                case .m4v: return "m4v"
                                default: return "mp4"
                                }
                            }()

                            let sourceExt = sourceURL.pathExtension.lowercased()
                            if sourceExt != desiredExt {
                                // 创建临时 remux 输出
                                let remuxURL = URL(fileURLWithPath: NSTemporaryDirectory())
                                    .appendingPathComponent("remux_\(item.id.uuidString)")
                                    .appendingPathExtension(desiredExt)

                                FFmpegVideoCompressor.remux(inputURL: sourceURL, outputURL: remuxURL) { remuxResult in
                                    DispatchQueue.main.async {
                                        switch remuxResult {
                                        case .success(let finalURL):
                                            let finalSize = (try? Data(contentsOf: finalURL).count) ?? item.originalSize
                                            item.compressedVideoURL = finalURL
                                            item.compressedSize = finalSize
                                            item.compressedResolution = item.originalResolution
                                            item.compressedFrameRate = item.frameRate  // remux 保持原始帧率
                                            item.compressedVideoCodec = item.videoCodec  // remux 保持原始编码
                                            print("✅ [remux] Original video remuxed to \(desiredExt), size: \(finalSize) bytes")
                                        case .failure:
                                            // remux 失败，退回到原始文件
                                            item.compressedVideoURL = sourceURL
                                            item.compressedSize = item.originalSize
                                            item.compressedResolution = item.originalResolution
                                            item.compressedFrameRate = item.frameRate  // 保持原始帧率
                                            item.compressedVideoCodec = item.videoCodec  // 保持原始编码
                                            print("⚠️ [remux] Failed, falling back to original video")
                                        }
                                    }
                                }
                            } else {
                                // 扩展名已经匹配，直接使用原视频
                                item.compressedVideoURL = sourceURL
                                item.compressedSize = item.originalSize
                                item.compressedResolution = item.originalResolution
                                item.compressedFrameRate = item.frameRate  // 保持原始帧率
                                item.compressedVideoCodec = item.videoCodec  // 保持原始编码
                            }

                            // 清理压缩后的临时文件（因为没使用它）
                            try? FileManager.default.removeItem(at: url)
                        } else {
                            print("✅ [Video Compression Check] Compression successful, reduced from \(item.originalSize) bytes to \(compressedSize) bytes")

                            // 使用压缩后的视频
                            item.compressedVideoURL = url
                            item.compressedSize = compressedSize

                            // 获取压缩后的视频信息（分辨率、帧率和编码）
                            Task {
                                let asset = AVURLAsset(url: url)
                                do {
                                    let tracks = try await asset.loadTracks(withMediaType: .video)
                                    if let videoTrack = tracks.first {
                                        let size = try await videoTrack.load(.naturalSize)
                                        let transform = try await videoTrack.load(.preferredTransform)
                                        let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                                        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                                        
                                        await MainActor.run {
                                            item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                                            item.compressedFrameRate = Double(nominalFrameRate)
                                        }
                                    }
                                } catch {
                                    print("Failed to load compressed video info: \(error)")
                                }
                                
                                // 检测压缩后的编码（使用异步版本）
                                if let codec = await MediaItem.detectVideoCodecAsync(from: url) {
                                    await MainActor.run {
                                        item.compressedVideoCodec = codec
                                    }
                                }
                            }
                        }
                        
                        // FFmpeg 使用 CRF 模式，不使用固定比特率
                        // 移除了误导性的比特率显示
                        
                        item.status = .completed
                        item.progress = 1.0
                    case .failure(let error):
                        item.status = .failed
                        item.errorMessage = error.localizedDescription
                    }
                    
                    // 恢复 continuation，让 async 函数继续执行
                    continuation.resume()
                }
            }
        )
        }
    }
}

#Preview {
    CompressionViewImage()
}
