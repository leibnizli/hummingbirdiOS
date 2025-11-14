//
//  AudioFormatConversionView.swift
//  hummingbird
//
//  Audio Format Conversion View
//

import SwiftUI
import PhotosUI
import AVFoundation
import ffmpegkit

struct AudioFormatConversionView: View {
    @State private var mediaItems: [MediaItem] = []
    @State private var isConverting = false
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
                        ForEach(AudioFormat.allCases) { format in
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
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select audio files to convert")
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
        .navigationTitle("Audio Format")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                Task {
                    await loadFilesFromURLs(urls)
                }
            } catch {
                print("File selection failed: \(error.localizedDescription)")
            }
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
        
        await convertAudio(item)
    }
    
    private func loadFilesFromURLs(_ urls: [URL]) async {
        await MainActor.run {
            AudioPlayerManager.shared.stop()
            mediaItems.removeAll()
        }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let fileExtension = url.pathExtension.lowercased()
            let mediaItem = MediaItem(pickerItem: nil, isVideo: false)
            
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
                
                await loadAudioMetadata(for: mediaItem, url: tempURL)
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // parseTimeString function will be added here
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
    
    private func convertAudio(_ item: MediaItem) async {
        print("[convertAudio] 开始音频转换")
        
        guard let sourceURL = item.sourceVideoURL else {
            print("❌ [convertAudio] 无法加载原始音频 URL")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始音频"
            }
            return
        }
        print("[convertAudio] 源音频 URL: \(sourceURL.path)")
        
        let targetFormat = settings.targetAudioFormat
        let outputExtension = targetFormat.fileExtension
        
        print("[convertAudio] 目标格式: \(targetFormat.rawValue)")
        
        // 如果源格式和目标格式相同，直接复制
        if item.fileExtension.lowercased() == outputExtension.lowercased() {
            print("✅ [convertAudio] 格式相同，直接复制")
            await MainActor.run {
                item.compressedVideoURL = sourceURL
                item.compressedSize = item.originalSize
                item.outputAudioFormat = targetFormat
                item.status = .completed
                item.progress = 1.0
            }
            return
        }
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("converted_\(UUID().uuidString)")
            .appendingPathExtension(outputExtension)
        
        print("[convertAudio] 输出 URL: \(outputURL.path)")
        
        // 获取音频时长用于进度计算
        let asset = AVURLAsset(url: sourceURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 构建 FFmpeg 命令
        var command = "-i \"\(sourceURL.path)\""
        
        switch targetFormat {
        case .mp3:
            command += " -c:a libmp3lame -b:a 192k -q:a 2"
        case .aac:
            command += " -c:a aac -b:a 192k"
        case .m4a:
            command += " -c:a aac -b:a 192k"
        case .opus:
            command += " -c:a libopus -b:a 128k -vbr on"
        case .flac:
            command += " -c:a flac -compression_level 8"
        case .wav:
            command += " -c:a pcm_s16le"
        }
        
        command += " \"\(outputURL.path)\""
        
        print("[convertAudio] FFmpeg 命令: ffmpeg \(command)")
        
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
                        print("✅ [convertAudio] FFmpeg 转换成功")
                        item.compressedVideoURL = outputURL
                        if let data = try? Data(contentsOf: outputURL) {
                            item.compressedSize = data.count
                            print("[convertAudio] 输出文件大小: \(data.count) bytes")
                        }
                        
                        // 获取转换后的音频信息
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
                            print("Failed to load converted audio info: \(error)")
                        }
                        
                        item.outputAudioFormat = targetFormat
                        item.status = .completed
                        item.progress = 1.0
                    } else {
                        print("❌ [convertAudio] FFmpeg 转换失败")
                        let errorMessage = session.getOutput() ?? "未知错误"
                        let lines = errorMessage.split(separator: "\n")
                        let errorLines = lines.suffix(5).joined(separator: "\n")
                        print("错误信息:\n\(errorLines)")
                        
                        // Check if error is due to missing encoder
                        var errorDescription = "音频转换失败"
                        if errorMessage.contains("Unknown encoder") || errorMessage.contains("Encoder not found") {
                            errorDescription = "编码器不可用，请尝试 AAC、M4A、FLAC 或 WAV 格式"
                        } else if errorMessage.contains("libmp3lame") {
                            errorDescription = "MP3 编码器不可用，请尝试 AAC 或 M4A 格式"
                        } else if errorMessage.contains("libopus") {
                            errorDescription = "OPUS 编码器不可用，请尝试 AAC 或 M4A 格式"
                        }
                        
                        item.status = .failed
                        item.errorMessage = errorDescription
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
        print("[convertAudio] 音频转换流程结束")
    }
    
    private func loadAudioMetadata(for mediaItem: MediaItem, url: URL) async {
        let asset = AVURLAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            await MainActor.run {
                mediaItem.duration = durationSeconds
            }
            
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
}
    
    #Preview {
        AudioFormatConversionView()
    }
