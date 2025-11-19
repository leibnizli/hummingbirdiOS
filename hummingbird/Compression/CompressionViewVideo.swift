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
import ffmpegkit

struct CompressionViewVideo: View {
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
        .navigationTitle("Video Compression")
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
            CompressionSettingsViewVideo(settings: settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.videos]))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie],
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
        // 停止当前播放
        await MainActor.run {
            AudioPlayerManager.shared.stop()
        }
        
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
                
                // 加载完成，设置为等待状态
                mediaItem.status = .pending
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
                // 标记 WebM 为不支持的格式
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = "WebM format is not supported. This app uses VideoToolbox (H.264/H.265) for video compression, which is incompatible with WebM container."
                }
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

                // 获取比特率（估算值，单位为 bits per second）
                let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)

                await MainActor.run {
                    mediaItem.originalResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                    mediaItem.frameRate = Double(nominalFrameRate)

                    // 转换为 kbps
                    if estimatedDataRate > 0 {
                        mediaItem.videoBitrate = Int(estimatedDataRate / 1000)
                        print("🎬 [Video Bitrate] Original: \(mediaItem.videoBitrate ?? 0) kbps")
                    }
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

        // AVFoundation 无法解析时，使用 FFprobe 兜底
        let needsFallback = {
            let durationValid = (mediaItem.duration ?? 0) > 0.0
            let frameRateValid = (mediaItem.frameRate ?? 0) > 0.0
            let resolutionValid = mediaItem.originalResolution != nil
            let pixelFormatValid = mediaItem.videoPixelFormat != nil || mediaItem.videoBitDepth != nil
            return !durationValid || !frameRateValid || !resolutionValid || !pixelFormatValid
        }()

        if needsFallback {
            await loadVideoMetadataFallback(for: mediaItem, url: url)
        }

        // 检测视频编码（使用异步版本更可靠）
        if let codec = await MediaItem.detectVideoCodecAsync(from: url) {
            await MainActor.run {
                mediaItem.videoCodec = codec

                // 记录编码信息，但不再限制格式
                // FFmpeg 会自动处理各种输入编码格式
                print("🎬 [Video Codec] 检测到编码: \(codec)")
            }
        }

        // 异步生成缩略图
        await generateVideoThumbnailOptimized(for: mediaItem, url: url)

        // 视频元数据加载完成，设置为等待状态
        await MainActor.run {
            // 只有在状态不是失败时才设置为 pending
            if mediaItem.status != .failed {
                mediaItem.status = .pending
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

    private func generateVideoThumbnailOptimized(for item: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        generator.apertureMode = .encodedPixels

        // 优化：设置更快的缩略图生成选项
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        // 针对 Dolby Vision 等特殊素材，尝试多个时间点
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let candidateSeconds: [Double] = {
            var seconds: [Double] = []
            if durationSeconds > 0 {
                let mid = max(0.1, durationSeconds / 2.0)
                seconds.append(min(1.0, mid))
            }
            seconds.append(contentsOf: [0.1, 0])
            return Array(Set(seconds)).sorted(by: >)
        }()

        for second in candidateSeconds {
            do {
                let time = CMTime(seconds: second, preferredTimescale: 600)
                let cgResult = try await generator.image(at: time)
                let thumbnail = UIImage(cgImage: cgResult.image)
                await MainActor.run {
                    item.thumbnailImage = thumbnail
                }
                return
            } catch {
                print("⚠️ [Thumbnail] Failed at \(second)s: \(error.localizedDescription)")
            }
        }

        if let fallbackImage = await generateVideoThumbnailViaFFmpeg(for: item, url: url, duration: durationSeconds) {
            await MainActor.run {
                item.thumbnailImage = fallbackImage
            }
            return
        }

        // 设置默认视频图标
        await MainActor.run {
            item.thumbnailImage = UIImage(systemName: "video.fill")
        }
    }

    private func loadVideoMetadataFallback(for mediaItem: MediaItem, url: URL) async {
        guard let info = await fetchFFprobeVideoInfo(url: url) else { return }
        await MainActor.run {
            if mediaItem.originalResolution == nil, let width = info.width, let height = info.height {
                mediaItem.originalResolution = CGSize(width: width, height: height)
            }
            if (mediaItem.duration ?? 0) <= 0, let duration = info.duration {
                mediaItem.duration = duration
            }
            if (mediaItem.frameRate ?? 0) <= 0, let fps = info.frameRate {
                mediaItem.frameRate = fps
            }
            if let pixelFormat = info.pixelFormat {
                mediaItem.videoPixelFormat = pixelFormat
            }
            if mediaItem.videoBitDepth == nil || mediaItem.videoBitDepth == 0 {
                mediaItem.videoBitDepth = MediaItem.deriveBitDepth(
                    pixelFormat: info.pixelFormat,
                    bitsPerRawSample: info.bitsPerRawSample
                )
            }
        }
    }

    private struct FFprobeVideoInfo {
        let width: Int?
        let height: Int?
        let duration: Double?
        let frameRate: Double?
        let pixelFormat: String?
        let bitsPerRawSample: Int?
    }

    private func fetchFFprobeVideoInfo(url: URL) async -> FFprobeVideoInfo? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<FFprobeVideoInfo?, Never>) in
            FFprobeKit.getMediaInformationAsync(url.path) { session in
                guard let info = session?.getMediaInformation() else {
                    continuation.resume(returning: nil)
                    return
                }
                let duration = Double(info.getDuration() ?? "") ?? 0
                var width: Int?
                var height: Int?
                var fps: Double?
                var pixelFormat: String?
                var bitsPerRawSample: Int?
                if let streams = info.getStreams() as? [StreamInformation] {
                    if let videoStream = streams.first(where: { ($0.getType() ?? "") == "video" }) {
                        if let widthValue = videoStream.getWidth()?.intValue {
                            width = widthValue
                        }
                        if let heightValue = videoStream.getHeight()?.intValue {
                            height = heightValue
                        }
                        if let frameRateString = videoStream.getAverageFrameRate(), !frameRateString.isEmpty {
                            fps = parseFrameRate(frameRateString)
                        } else if let frameRateString = videoStream.getRealFrameRate(), !frameRateString.isEmpty {
                            fps = parseFrameRate(frameRateString)
                        }

                        let pixelFormatCandidates: [String?] = [
                            videoStream.getStringProperty("pix_fmt"),
                            videoStream.getStringProperty("pixel_format"),
                            videoStream.getStringProperty("pixel_format_name")
                        ]
                        pixelFormat = pixelFormatCandidates
                            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .first(where: { !$0.isEmpty })

                        if let bitsString = videoStream.getStringProperty("bits_per_raw_sample"),
                           let value = Int(bitsString) {
                            bitsPerRawSample = value
                        }
                    }
                }
                continuation.resume(returning: FFprobeVideoInfo(
                    width: width,
                    height: height,
                    duration: duration > 0 ? duration : nil,
                    frameRate: (fps ?? 0) > 0 ? fps : nil,
                    pixelFormat: pixelFormat,
                    bitsPerRawSample: bitsPerRawSample
                ))
            }
        }
    }

    private func parseFrameRate(_ value: String) -> Double? {
        if value.contains("/") {
            let parts = value.split(separator: "/")
            if parts.count == 2,
               let numerator = Double(parts[0]),
               let denominator = Double(parts[1]),
               denominator != 0 {
                return numerator / denominator
            }
        }
        return Double(value)
    }

    private func generateVideoThumbnailViaFFmpeg(for item: MediaItem, url: URL, duration: Double) async -> UIImage? {
        let capturePoint: Double
        if duration.isFinite && duration > 0.0 {
            capturePoint = min(max(duration / 2.0, 0.1), 5.0)
        } else {
            capturePoint = 0.5
        }

        return await withCheckedContinuation { continuation in
            FFmpegVideoCompressor.extractThumbnail(from: url, at: capturePoint) { result in
                switch result {
                case .success(let outputURL):
                    let image = (try? Data(contentsOf: outputURL)).flatMap { UIImage(data: $0) }
                    try? FileManager.default.removeItem(at: outputURL)
                    if let image = image {
                        print("✅ [Thumbnail] Generated via FFmpeg at \(capturePoint)s")
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    print("❌ [Thumbnail] FFmpeg fallback failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
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
                    item.infoMessage = nil
                }
            }

            for item in mediaItems {
                // 跳过 WebM 文件（已标记为失败）
                if item.fileExtension == "webm" {
                    await MainActor.run {
                        if item.status != .failed {
                            item.status = .failed
                            item.errorMessage = "WebM format is not supported"
                        }
                    }
                    continue
                }
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
            item.infoMessage = nil
            item.status = .compressing
            item.progress = 0
        }

        await compressVideo(item)
    }

    private func compressVideo(_ item: MediaItem) async {
        // 检查是否为不支持的 WebM 格式
        if item.fileExtension == "webm" {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "WebM format is not supported"
            }
            return
        }

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

        // Dolby Vision (dvhe/dvh1 etc.) cannot retain metadata after re-encoding.
        if MediaItem.isDolbyVisionCodec(item.videoCodec) {
            await preserveDolbyVisionStream(for: item, sourceURL: sourceURL, desiredOutputFileType: desiredOutputFileType)
            return
        }

        // 使用 continuation 等待压缩完成
        await withCheckedContinuation { continuation in
            MediaCompressor.compressVideo(
                at: sourceURL,
                settings: settings,
                outputFileType: desiredOutputFileType,
                originalFrameRate: item.frameRate,
                originalResolution: item.originalResolution,
                originalBitDepth: item.videoBitDepth,
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
                                        let estimatedDataRate = try await videoTrack.load(.estimatedDataRate)
                                        
                                        await MainActor.run {
                                            item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                                            item.compressedFrameRate = Double(nominalFrameRate)
                                            
                                            // 记录压缩后比特率
                                            if estimatedDataRate > 0 {
                                                item.compressedVideoBitrate = Int(estimatedDataRate / 1000)
                                                print("🎬 [Video Bitrate] Compressed: \(item.compressedVideoBitrate ?? 0) kbps")
                                            }
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

    private func preserveDolbyVisionStream(for item: MediaItem, sourceURL: URL, desiredOutputFileType: AVFileType) async {
        await MainActor.run {
            item.progress = 0.05
        }

        let desiredExt: String = {
            switch desiredOutputFileType {
            case .mov: return "mov"
            case .m4v: return "m4v"
            default: return "mp4"
            }
        }()

        // Dolby Vision 不支持 m4v 容器，自动回退到 mp4
        let fallbackToMP4 = (desiredExt == "m4v")
        let targetExt: String = fallbackToMP4 ? "mp4" : desiredExt
        if fallbackToMP4 {
            print("⚠️ [Dolby Vision] M4V does not preserve Dolby Vision metadata. Falling back to mp4 container.")
        }

        await MainActor.run {
            if item.outputVideoFormat?.lowercased() != targetExt {
                item.outputVideoFormat = targetExt
            }
        }

        let sourceExt = sourceURL.pathExtension.lowercased()

        // 如果容器一致，直接复用原始文件
        if sourceExt == targetExt {
            await MainActor.run {
                item.compressedVideoURL = sourceURL
                item.compressedSize = item.originalSize
                item.compressedResolution = item.originalResolution
                item.compressedFrameRate = item.frameRate
                item.compressedVideoCodec = item.videoCodec
                item.errorMessage = nil
                if fallbackToMP4 {
                    item.infoMessage = "Dolby Vision detected. Kept original video and switched container to MP4 to preserve metadata."
                } else {
                    item.infoMessage = "Dolby Vision detected. Original video kept without recompression."
                }
                item.progress = 1.0
                item.status = .completed
            }
            return
        }

        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("dolbyvision_\(item.id.uuidString)")
            .appendingPathExtension(targetExt)

        await withCheckedContinuation { continuation in
            FFmpegVideoCompressor.remux(inputURL: sourceURL, outputURL: outputURL) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let finalURL):
                        let finalSize = (try? Data(contentsOf: finalURL).count) ?? item.originalSize
                        item.compressedVideoURL = finalURL
                        item.compressedSize = finalSize
                        item.compressedResolution = item.originalResolution
                        item.compressedFrameRate = item.frameRate
                        item.compressedVideoCodec = item.videoCodec
                        item.errorMessage = nil
                        if fallbackToMP4 {
                            item.infoMessage = "Dolby Vision detected. Remuxed to MP4 to preserve Dolby Vision metadata."
                        } else {
                            item.infoMessage = "Dolby Vision detected. Remuxed without recompression to keep Dolby Vision metadata."
                        }
                        item.progress = 1.0
                        item.status = .completed
                        print("✅ [Dolby Vision] Remux successful. Metadata preserved in .\(targetExt)")
                    case .failure(let error):
                        item.infoMessage = nil
                        item.status = .failed
                        item.errorMessage = error.localizedDescription
                        print("❌ [Dolby Vision] Remux failed: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
    }
}

#Preview {
    CompressionViewVideo()
}
