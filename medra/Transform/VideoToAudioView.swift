//
//  VideoToAudioView.swift
//  hummingbird
//
//  Video to Audio Extraction View
//

import SwiftUI
import PhotosUI
import AVFoundation
import ffmpegkit

struct VideoToAudioView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isConverting = false
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @StateObject private var settings = FormatSettings()
    
    private var hasLoadingItems: Bool {
        mediaItems.contains { $0.status == .loading }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部按钮
            VStack(spacing: 0) {
                HStack(spacing: 12) {
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
                            Text("Add Videos")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isConverting || hasLoadingItems)
                    
                    Button(action: startConversion) {
                        HStack(spacing: 6) {
                            if isConverting || hasLoadingItems {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isConverting ? "Processing" : hasLoadingItems ? "Loading" : "Start")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mediaItems.isEmpty || isConverting || hasLoadingItems ? .gray : .green)
                    .disabled(mediaItems.isEmpty || isConverting || hasLoadingItems)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemGroupedBackground))
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            
            //MARK: 设置区域
            VStack(spacing: 0) {
                HStack {
                    Text("Target Audio Format")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $settings.targetAudioFormat) {
                        ForEach(AudioFormat.allCases.filter { $0 != .original }) { format in
                            Text("\(format.rawValue) · \(format.description)")
                                .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            .background(Color(uiColor: .systemBackground))
            
            // 文件列表
            if mediaItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select videos to extract audio")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mediaItems) { item in
                        FormatItemRow(item: item, showPhotosSaveButton: false)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.visible)
                    }
                    .onDelete { indexSet in
                        guard !isConverting && !hasLoadingItems else { return }
                        
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
                    .deleteDisabled(isConverting || hasLoadingItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Video to Audio")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .videos)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.movie, .video], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                Task {
                    await loadFilesFromURLs(urls)
                }
            } catch {
                print("File selection failed: \(error.localizedDescription)")
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
        .onDisappear {
            AudioPlayerManager.shared.stop()
        }
    }
    
    private func startConversion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isConverting = true
        }
        
        Task {
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedVideoURL = nil
                    item.compressedSize = 0
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await convertItem(item)
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConverting = false
                }
            }
        }
    }
    
    private func convertItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await extractAudio(item)
    }
    
    // 从相册选择
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            AudioPlayerManager.shared.stop()
        }
        
        for item in items {
            let mediaItem = MediaItem(pickerItem: item, isVideo: true)
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            await loadVideoItemOptimized(item, mediaItem)
        }
    }
    
    private func loadVideoItemOptimized(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        // 检测视频格式
        var detectedFormat = "video"
        
        // 检查所有支持的内容类型
        for contentType in item.supportedContentTypes {
            if let ext = contentType.preferredFilenameExtension?.lowercased(),
               ["mov", "mp4", "avi", "mkv", "webm", "m4v"].contains(ext) {
                detectedFormat = ext
                break
            }
        }
        
        await MainActor.run {
            mediaItem.fileExtension = detectedFormat
        }
        
        // 先尝试使用 URL 方式加载（更高效）
        if let url = try? await item.loadTransferable(type: URL.self) {
            await MainActor.run {
                mediaItem.sourceVideoURL = url
                
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int {
                    mediaItem.originalSize = fileSize
                }
                
                mediaItem.status = .pending
                
                Task {
                    await loadVideoMetadata(for: mediaItem, url: url)
                }
            }
        } else if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
            }
            
            let detectedExtension = mediaItem.fileExtension.isEmpty ? "mp4" : mediaItem.fileExtension
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                .appendingPathExtension(detectedExtension)
            
            do {
                try data.write(to: tempURL)
                
                await MainActor.run {
                    mediaItem.sourceVideoURL = tempURL
                    mediaItem.status = .pending
                    
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
            await MainActor.run {
                mediaItem.status = .failed
                mediaItem.errorMessage = "Unable to load video file"
            }
        }
    }
    
    private func loadFilesFromURLs(_ urls: [URL]) async {
        await MainActor.run {
            AudioPlayerManager.shared.stop()
        }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let fileExtension = url.pathExtension.lowercased()
            let mediaItem = MediaItem(pickerItem: nil, isVideo: true)
            
            await MainActor.run {
                mediaItem.fileExtension = fileExtension
                mediaItems.append(mediaItem)
            }
            
            do {
                let data = try Data(contentsOf: url)
                
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                }
                
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                    .appendingPathExtension(fileExtension)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    mediaItem.sourceVideoURL = tempURL
                    mediaItem.status = .pending
                }
                
                await loadVideoMetadata(for: mediaItem, url: tempURL)
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.split(separator: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    private func extractAudio(_ item: MediaItem) async {
        print("[extractAudio] 开始音频提取")
        
        guard let sourceURL = item.sourceVideoURL else {
            print("❌ [extractAudio] 无法加载原始视频 URL")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        print("[extractAudio] 源视频 URL: \(sourceURL.path)")
        
        let targetFormat = settings.targetAudioFormat
        let outputExtension = targetFormat.fileExtension
        
        print("[extractAudio] 目标格式: \(targetFormat.rawValue)")
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("extracted_\(UUID().uuidString)")
            .appendingPathExtension(outputExtension)
        
        print("[extractAudio] 输出 URL: \(outputURL.path)")
        
        // 获取视频时长用于进度计算
        let asset = AVURLAsset(url: sourceURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 构建 FFmpeg 命令
        var command = "-i \"\(sourceURL.path)\""
        
        switch targetFormat {
        case .original:
            // 理论上不应该走到这里，因为 UI 过滤了 original
            command += " -vn -c:a copy"
        case .mp3:
            command += " -vn -c:a libmp3lame -b:a 192k -q:a 2"
        case .m4a:
            command += " -vn -c:a aac -b:a 192k"
        case .flac:
            command += " -vn -c:a flac -compression_level 8"
        case .wav:
            command += " -vn -c:a pcm_s16le"
        case .webm:
            command += " -vn -c:a libopus -b:a 128k -vbr on"
        }
        
        command += " \"\(outputURL.path)\""
        
        print("[extractAudio] FFmpeg 命令: ffmpeg \(command)")
        
        await withCheckedContinuation { continuation in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session = session else {
                    Task { @MainActor in
                        item.status = .failed
                        item.errorMessage = "FFmpeg session 创建失败"
                        continuation.resume()
                    }
                    return
                }
                
                let returnCode = session.getReturnCode()
                
                Task { @MainActor in
                    if ReturnCode.isSuccess(returnCode) {
                        print("✅ [extractAudio] FFmpeg 提取成功")
                        item.compressedVideoURL = outputURL
                        if let data = try? Data(contentsOf: outputURL) {
                            item.compressedSize = data.count
                            print("[extractAudio] 输出文件大小: \(data.count) bytes")
                        }
                        
                        // 获取转换后的音频信息
                        Task {
                            let resultAsset = AVURLAsset(url: outputURL)
                            do {
                                let tracks = try await resultAsset.loadTracks(withMediaType: .audio)
                                if let audioTrack = tracks.first {
                                    let formatDescriptions = audioTrack.formatDescriptions as! [CMFormatDescription]
                                    if let formatDescription = formatDescriptions.first {
                                        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                                        
                                        if let asbd = audioStreamBasicDescription {
                                            let sampleRate = Int(asbd.pointee.mSampleRate)
                                            let channels = Int(asbd.pointee.mChannelsPerFrame)
                                            
                                            await MainActor.run {
                                                item.compressedAudioSampleRate = sampleRate
                                                item.compressedAudioChannels = channels
                                            }
                                        }
                                    }
                                    
                                    if let estimatedBitrate = try? await audioTrack.load(.estimatedDataRate) {
                                        let bitrateKbps = Int(estimatedBitrate / 1000)
                                        await MainActor.run {
                                            item.compressedAudioBitrate = bitrateKbps
                                        }
                                    }
                                }
                            } catch {
                                print("Failed to load converted audio info: \(error)")
                            }
                        }
                        
                        item.outputAudioFormat = targetFormat
                        item.status = .completed
                        item.progress = 1.0
                    } else {
                        print("❌ [extractAudio] FFmpeg 提取失败")
                        let errorMessage = session.getOutput() ?? "未知错误"
                        let lines = errorMessage.split(separator: "\n")
                        let errorLines = lines.suffix(5).joined(separator: "\n")
                        print("错误信息:\n\(errorLines)")
                        
                        item.status = .failed
                        item.errorMessage = "音频提取失败"
                    }
                    continuation.resume()
                }
            }, withLogCallback: { log in
                guard let log = log else { return }
                let message = log.getMessage() ?? ""
                
                // 解析进度
                if message.contains("time=") {
                    if let timeRange = message.range(of: "time=([0-9:.]+)", options: .regularExpression) {
                        let timeString = String(message[timeRange]).replacingOccurrences(of: "time=", with: "")
                        if let currentTime = self.parseTimeString(timeString), duration > 0 {
                            let progress = Float(currentTime / duration)
                            Task { @MainActor in
                                item.progress = min(progress, 0.99)
                            }
                        }
                    }
                }
            }, withStatisticsCallback: { statistics in
                guard let statistics = statistics else { return }
                let time = Double(statistics.getTime()) / 1000.0
                if duration > 0 {
                    let progress = Float(time / duration)
                    Task { @MainActor in
                        item.progress = min(progress, 0.99)
                    }
                }
            })
        }
        print("[extractAudio] 音频提取流程结束")
    }
    
    private func loadVideoMetadata(for mediaItem: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            await MainActor.run {
                mediaItem.duration = durationSeconds
            }
            
            // 尝试获取音频轨道信息
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = tracks.first {
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
                
                if let estimatedBitrate = try? await audioTrack.load(.estimatedDataRate), estimatedBitrate > 0 {
                    let bitrateKbps = Int(estimatedBitrate / 1000)
                    await MainActor.run {
                        mediaItem.audioBitrate = bitrateKbps
                    }
                }
            }
            
            // 生成缩略图
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 0, preferredTimescale: 600)
            if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                await MainActor.run {
                    mediaItem.thumbnailImage = image
                }
            }
            
            await MainActor.run {
                mediaItem.status = .pending
            }
        } catch {
            print("Failed to load video metadata: \(error)")
            await MainActor.run {
                mediaItem.status = .failed
                mediaItem.errorMessage = "Failed to load video metadata"
            }
        }
    }
}

#Preview {
    VideoToAudioView()
}
