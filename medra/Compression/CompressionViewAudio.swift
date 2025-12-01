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

struct CompressionViewAudio: View {
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
                    Button(action: { showingFilePicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Files")
                                .font(.system(size: 15, weight: .semibold))
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
        .navigationTitle("Audio Compression")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            CompressionSettingsViewAudio(settings: settings)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
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
        .onDisappear {
            // 页面离开时停止音频播放
            AudioPlayerManager.shared.stop()
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
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    private func loadAudioMetadata(for mediaItem: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        var avFoundationSuccess = false
        
        // Try AVFoundation first
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // Only consider it a success if we got a valid duration
            if durationSeconds > 0 {
                await MainActor.run {
                    mediaItem.duration = durationSeconds
                }
                
                // Load audio tracks info
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                if let audioTrack = tracks.first {
                    // Get format description
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
                    
                    // Try to estimate bitrate
                    if let estimatedBitrate = try? await audioTrack.load(.estimatedDataRate), estimatedBitrate > 0 {
                        let bitrateKbps = Int(estimatedBitrate / 1000)
                        await MainActor.run {
                            mediaItem.audioBitrate = bitrateKbps
                        }
                        print("✅ [Audio Metadata] AVFoundation detected bitrate: \(bitrateKbps) kbps")
                    } else {
                        // AVFoundation failed to get bitrate, try FFmpeg for just bitrate
                        print("⚠️ [Audio Metadata] AVFoundation failed to get bitrate, trying FFmpeg")
                        
                        if let ffmpegInfo = await FFmpegAudioProbe.probeAudioFile(at: url) {
                            await MainActor.run {
                                if let bitrate = ffmpegInfo.bitrate {
                                    mediaItem.audioBitrate = bitrate
                                    print("✅ [Audio Metadata] FFmpeg detected bitrate: \(bitrate) kbps")
                                }
                                
                                // Also fill in other missing info if needed
                                if mediaItem.audioSampleRate == nil, let sampleRate = ffmpegInfo.sampleRate {
                                    mediaItem.audioSampleRate = sampleRate
                                }
                                if mediaItem.audioChannels == nil, let channels = ffmpegInfo.channels {
                                    mediaItem.audioChannels = channels
                                }
                            }
                        } else {
                            // FFmpeg also failed, try calculation
                            print("⚠️ [Audio Metadata] FFmpeg probe failed, trying calculation")
                            if let calculatedBitrate = FFmpegAudioProbe.calculateAverageBitrate(fileURL: url, duration: durationSeconds) {
                                await MainActor.run {
                                    mediaItem.audioBitrate = calculatedBitrate
                                    print("✅ [Audio Metadata] Calculated average bitrate: \(calculatedBitrate) kbps")
                                }
                            }
                        }
                    }
                }
                
                // Mark as success and pending
                await MainActor.run {
                    mediaItem.status = .pending
                }
                avFoundationSuccess = true
            }
        } catch {
            print("⚠️ [Audio Metadata] AVFoundation failed: \(error)")
        }
        
        // If AVFoundation completely failed (e.g. couldn't load duration), try full FFmpeg fallback
        if !avFoundationSuccess {
            print("🔄 [Audio Metadata] AVFoundation failed or invalid, trying full FFmpeg fallback...")
            
            if let ffmpegInfo = await FFmpegAudioProbe.probeAudioFile(at: url) {
                await MainActor.run {
                    // Use FFmpeg detected info
                    if let duration = ffmpegInfo.duration, duration > 0 {
                        mediaItem.duration = duration
                    }
                    
                    if let bitrate = ffmpegInfo.bitrate {
                        mediaItem.audioBitrate = bitrate
                    }
                    
                    if let sampleRate = ffmpegInfo.sampleRate {
                        mediaItem.audioSampleRate = sampleRate
                    }
                    
                    if let channels = ffmpegInfo.channels {
                        mediaItem.audioChannels = channels
                    }
                    
                    // If we got at least duration, consider it a success
                    if (ffmpegInfo.duration ?? 0) > 0 {
                        mediaItem.status = .pending
                        print("✅ [Audio Metadata] Full FFmpeg fallback successful")
                    } else {
                        mediaItem.status = .failed
                        mediaItem.errorMessage = "Could not determine audio duration"
                    }
                }
            } else {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = "Failed to load audio metadata (AVFoundation & FFmpeg)"
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
        
        // 视频元数据加载完成，设置为等待状态
        await MainActor.run {
            mediaItem.status = .pending
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
        await compressAudio(item)
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
        // 特殊处理：WAV 是无压缩格式，无法通过比特率压缩，自动转换为 MP3
        let outputFormat: AudioFormat
        if settings.audioFormat == .original {
            // 根据文件扩展名确定格式
            let ext = item.fileExtension.lowercased()
            switch ext {
            case "mp3": outputFormat = .mp3
            case "m4a": outputFormat = .m4a
            case "flac":
                // FLAC 是无损格式，无法指定目标比特率，自动转换为 MP3
                outputFormat = .mp3
                print("⚠️ [Audio Format] FLAC is lossless and cannot be compressed by target bitrate. Auto-converting to MP3 for compression.")
            case "wav":
                // WAV 无法压缩，自动转换为 MP3
                outputFormat = .mp3
                print("⚠️ [Audio Format] WAV is uncompressed and cannot be compressed by bitrate. Auto-converting to MP3 for compression.")
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
}

#Preview {
    CompressionViewAudio()
}
