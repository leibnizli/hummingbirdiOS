//
//  CompressionItemRow.swift
//  hummingbird
//
//  压缩功能的媒体项行视图
//

import SwiftUI
import Photos
import AVFoundation

struct CompressionItemRow: View {
    @ObservedObject var item: MediaItem
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var showingToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 音频播放进度条（仅在播放时显示）
            if item.isAudio && audioPlayer.isCurrentAudio(itemId: item.id) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        
                        // 进度
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * audioPlayer.getProgress(for: item.id))
                    }
                }
                .frame(height: 3)
                .animation(.linear(duration: 0.1), value: audioPlayer.currentTime)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    // 预览图
                    ZStack {
                        // 音频文件使用渐变背景
                        if item.isAudio {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple.opacity(0.7),
                                    Color.pink.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            // 播放/暂停按钮
                            // 优先使用压缩后的音频，如果没有则使用原始音频
                            if let audioURL = item.compressedVideoURL ?? item.sourceVideoURL {
                                Button(action: {
                                    audioPlayer.togglePlayPause(itemId: item.id, audioURL: audioURL)
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.75))
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: audioPlayer.isPlaying(itemId: item.id) ? "pause.fill" : "play.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.purple)
                                            .offset(x: audioPlayer.isPlaying(itemId: item.id) ? 0 : 2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Color.gray.opacity(0.2)
                            
                            if let thumbnail = item.thumbnailImage {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // 信息区域
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: item.isAudio ? "music.note" : (item.isVideo ? "video.circle.fill" : "photo.circle.fill"))
                                .foregroundStyle(item.isAudio ? .purple : (item.isVideo ? .blue : .green))
                            
                            // 文件格式
                            if item.status == .completed {
                                // 根据文件类型获取原始格式
                                let originalFormat: String = {
                                    if item.isImage {
                                        return item.originalImageFormat?.rawValue.uppercased() ?? item.fileExtension.uppercased()
                                    } else if item.isVideo {
                                        return item.fileExtension.uppercased()
                                    } else if item.isAudio {
                                        return item.fileExtension.uppercased()
                                    }
                                    return ""
                                }()
                                
                                // 根据文件类型获取输出格式
                                let outputFormat: String = {
                                    if item.isImage {
                                        return item.outputImageFormat?.rawValue.uppercased() ?? ""
                                    } else if item.isVideo {
                                        return item.outputVideoFormat?.uppercased() ?? ""
                                    } else if item.isAudio {
                                        return item.outputAudioFormat?.rawValue.uppercased() ?? ""
                                    }
                                    return ""
                                }()
                                
                                if !originalFormat.isEmpty {
                                    if outputFormat.isEmpty || originalFormat == outputFormat {
                                        // 如果格式没有变化或未指定输出格式，只显示原始格式
                                        Text(originalFormat)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    } else {
                                        // 如果格式有变化，显示转换过程
                                        Text(originalFormat)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(outputFormat)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    
                                    // WebP 动画标识（压缩后）
                                    if item.isAnimatedWebP && (originalFormat == "WEBP" || outputFormat == "WEBP") {
                                        if item.preservedAnimation {
                                            // 保留了动画
                                            HStack(spacing: 2) {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.caption2)
                                                Text("\(item.webpFrameCount) frames")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundStyle(.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        } else {
                                            // 转为静态
                                            HStack(spacing: 2) {
                                                Image(systemName: "photo.fill")
                                                    .font(.caption2)
                                                Text("Static")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                }
                            } else {
                                // 未完成时只显示原始格式
                                if !item.fileExtension.isEmpty {
                                    Text(item.fileExtension.uppercased())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                
                                // WebP 动画标识（压缩前）
                                if item.isAnimatedWebP && item.fileExtension.uppercased() == "WEBP" {
                                    HStack(spacing: 2) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.caption2)
                                        if item.webpFrameCount > 0 {
                                            Text("\(item.webpFrameCount) frames")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        } else {
                                            Text("Animated")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            
                            Spacer()
                            
                            // 状态标识
                            statusBadge
                        }
                        
                        //MARK: 文件大小和压缩信息
                        if item.status == .completed {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Size: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // 显示分辨率变化（仅图片和视频）
                                if !item.isAudio {
                                    if let originalRes = item.originalResolution, let compressedRes = item.compressedResolution {
                                        // 判断分辨率是否有变化（允许1像素的误差）
                                        if abs(originalRes.width - compressedRes.width) > 1 || abs(originalRes.height - compressedRes.height) > 1 {
                                            Text("Resolution: \(item.formatResolution(originalRes)) → \(item.formatResolution(compressedRes))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Resolution: \(item.formatResolution(compressedRes))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if let resolution = item.originalResolution {
                                        Text("Resolution: \(item.formatResolution(resolution))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示 PNG 压缩参数
                                    if item.outputImageFormat == .png, let params = item.pngCompressionParams {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("PNG Params:")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.blue)
                                            Text("Iterations: \(params.numIterations), Large: \(params.numIterationsLarge)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            
                                            // 显示 Lossy Transparent 状态
                                            if params.actualLossyTransparent {
                                                Text("✓ lossy_transparent enabled")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                            
                                            // 显示 Lossy 8-bit 状态
                                            if params.actualLossy8bit {
                                                Text("✓ lossy_8bit enabled")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                            
                                            // 如果都没有启用
                                            if !params.actualLossyTransparent && !params.actualLossy8bit {
                                                Text("Lossy: disabled (lossless)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                // 显示音频参数（仅音频）
                                if item.isAudio {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示比特率变化
                                    if let compressedBitrate = item.compressedAudioBitrate {
                                        if let originalBitrate = item.audioBitrate {
                                            // 原始和压缩后都有值
                                            if originalBitrate != compressedBitrate {
                                                Text("Bitrate: \(item.formatAudioBitrate(originalBitrate)) → \(item.formatAudioBitrate(compressedBitrate))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Bitrate: \(item.formatAudioBitrate(originalBitrate))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        } else {
                                            // 原始未知，但压缩后检测到了
                                            Text("Bitrate: Unknown → \(item.formatAudioBitrate(compressedBitrate))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        // 只显示原始值（或 Unknown）
                                        Text("Bitrate: \(item.formatAudioBitrate(item.audioBitrate))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示采样率变化
                                    if let originalSampleRate = item.audioSampleRate, let compressedSampleRate = item.compressedAudioSampleRate {
                                        if originalSampleRate != compressedSampleRate {
                                            Text("Sample Rate: \(item.formatAudioSampleRate(originalSampleRate)) → \(item.formatAudioSampleRate(compressedSampleRate))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Sample Rate: \(item.formatAudioSampleRate(originalSampleRate))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Sample Rate: \(item.formatAudioSampleRate(item.audioSampleRate))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示声道变化
                                    if let originalChannels = item.audioChannels, let compressedChannels = item.compressedAudioChannels {
                                        if originalChannels != compressedChannels {
                                            Text("Channels: \(item.formatAudioChannels(originalChannels)) → \(item.formatAudioChannels(compressedChannels))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Channels: \(item.formatAudioChannels(originalChannels))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Channels: \(item.formatAudioChannels(item.audioChannels))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                // 显示视频时长、帧率和编码（仅视频）
                                else if item.isVideo {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示帧率变化
                                    if let originalFPS = item.frameRate, let compressedFPS = item.compressedFrameRate {
                                        // 判断帧率是否有变化（允许0.1的误差）
                                        if abs(originalFPS - compressedFPS) > 0.1 {
                                            Text("Frame Rate: \(item.formatFrameRate(originalFPS)) → \(item.formatFrameRate(compressedFPS))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Frame Rate: \(item.formatFrameRate(originalFPS))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Frame Rate: \(item.formatFrameRate(item.frameRate))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示编码变化
                                    if let originalCodec = item.videoCodec, let compressedCodec = item.compressedVideoCodec {
                                        if originalCodec != compressedCodec {
                                            Text("Codec: \(originalCodec) → \(compressedCodec)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Codec: \(originalCodec)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if let codec = item.videoCodec {
                                        Text("Codec: \(codec)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                HStack {
                                    Text("Saved: \(item.formatBytes(item.savedSize))")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Spacer()
                                    Text("Ratio: \(String(format: "%.1f%%", item.compressionRatio * 100))")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Size: \(item.formatBytes(item.originalSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                // 显示分辨率（仅图片和视频）
                                if !item.isAudio, let resolution = item.originalResolution {
                                    Text("Resolution: \(item.formatResolution(resolution))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                // 显示音频参数（仅音频）
                                if item.isAudio {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Bitrate: \(item.formatAudioBitrate(item.audioBitrate))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Sample Rate: \(item.formatAudioSampleRate(item.audioSampleRate))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Channels: \(item.formatAudioChannels(item.audioChannels))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                // 显示视频时长、帧率和编码（仅视频）
                                else if item.isVideo {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示帧率变化
                                    if let originalFPS = item.frameRate, let compressedFPS = item.compressedFrameRate {
                                        // 判断帧率是否有变化（允许0.1的误差）
                                        if abs(originalFPS - compressedFPS) > 0.1 {
                                            Text("Frame Rate: \(item.formatFrameRate(originalFPS)) → \(item.formatFrameRate(compressedFPS))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Frame Rate: \(item.formatFrameRate(originalFPS))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("Frame Rate: \(item.formatFrameRate(item.frameRate))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示编码
                                    if let codec = item.videoCodec {
                                        Text("Codec: \(codec)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // 进度条
                        if item.status == .compressing {
                            ProgressView(value: Double(item.progress))
                                .tint(.blue)
                        }
                        
                        // 错误信息
                        if let error = item.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }
                }
                
                // 保存按钮
                if item.status == .completed {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            // Photos 按钮（仅图片和视频）
                            if !item.isAudio {
                                Button(action: { saveToPhotos(item) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo.badge.arrow.down")
                                            .font(.caption)
                                        Text("Photos")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            Button(action: { saveToICloud(item) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .font(.caption)
                                    Text("iCloud")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { shareFile(item) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                    Text("Share")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }.padding(.vertical, 8)
                .toast(isShowing: $showingToast, message: "Saved Successfully")
        }
    }
    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .loading:
            HStack(spacing: 3) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .pending:
            HStack(spacing: 3) {
                Image(systemName: "clock")
                Text("Pending")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case .compressing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Compressing")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .processing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Processing")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .completed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                Text("Completed")
            }
            .font(.caption)
            .foregroundStyle(.green)
            .lineLimit(1)
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "xmark.circle.fill")
                Text("Failed")
            }
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(1)
        }
    }
    
    private func saveToPhotos(_ item: MediaItem) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                print("相册权限被拒绝")
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if item.isAudio {
                        // 音频文件不能直接保存到相册，这个分支不应该被执行到
                        // 因为音频文件不显示 Photos 按钮
                        print("⚠️ Audio files cannot be saved to Photos, please use iCloud or Share")
                        return
                    } else if item.isVideo, let url = item.compressedVideoURL {
                        // 检查文件是否存在
                        guard FileManager.default.fileExists(atPath: url.path) else {
                            print("❌ 视频文件不存在: \(url.path)")
                            return
                        }
                        
                        // 创建一个兼容的副本，保持原始扩展名
                        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                        let compatibleURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("save_\(UUID().uuidString).\(fileExtension)")
                        
                        // 复制文件
                        try? FileManager.default.copyItem(at: url, to: compatibleURL)
                        
                        // 使用 AVAsset 获取视频信息
                        let asset = AVURLAsset(url: compatibleURL)
                        if asset.tracks(withMediaType: .video).isEmpty {
                            print("❌ 无效的视频文件")
                            return
                        }
                        
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: compatibleURL)
                        
                        // 延迟清理临时文件
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            try? FileManager.default.removeItem(at: compatibleURL)
                        }
                    } else if let data = item.compressedData {
                        // 使用 PHAssetCreationRequest.forAsset() 保存原始数据
                        // 这样可以保留动画 WebP 等特殊格式
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: data, options: nil)
                        print("✅ [CompressionItemRow] 保存图片，大小: \(data.count) bytes，格式: \(item.outputImageFormat?.rawValue ?? "unknown")")
                    }
                }
                await MainActor.run {
                    withAnimation {
                        showingToast = true
                    }
                }
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToICloud(_ item: MediaItem) {
        print("🔵 [iCloud] 使用文档选择器保存")
        
        // 准备临时文件
        var fileURL: URL?
        
        if item.isAudio, let url = item.compressedVideoURL {
            fileURL = url
        } else if item.isVideo, let url = item.compressedVideoURL {
            fileURL = url
        } else if let data = item.compressedData {
            let fileExtension: String
            switch item.outputImageFormat {
            case .heic:
                fileExtension = "heic"
            case .png:
                fileExtension = "png"
            case .webp:
                fileExtension = "webp"
            default:
                fileExtension = "jpg"
            }
            
            let fileName = "hummingbird_\(Date().timeIntervalSince1970).\(fileExtension)"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                fileURL = tempURL
            } catch {
                print("❌ [iCloud] 创建临时文件失败")
                return
            }
        }
        
        guard let sourceURL = fileURL,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // 创建文档选择器 - 导出模式
        let documentPicker = UIDocumentPickerViewController(forExporting: [sourceURL], asCopy: true)
        
        // 创建 coordinator 来处理回调
        let coordinator = DocumentPickerCoordinator { success in
            Task { @MainActor in
                if success {
                    withAnimation {
                        self.showingToast = true
                    }
                    print("✅ [iCloud] 文件保存成功")
                } else {
                    print("⚠️ [iCloud] 用户取消保存")
                }
            }
        }
        documentPicker.delegate = coordinator
        
        // 保持 coordinator 的引用
        objc_setAssociatedObject(documentPicker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
        
        // iPad 需要设置 popover
        if let popover = documentPicker.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        print("📤 [iCloud] 显示文档选择器")
        rootViewController.present(documentPicker, animated: true)
    }
    
    // Document Picker Coordinator
    private class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Bool) -> Void
        
        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(true)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(false)
        }
    }
    
    private func shareFile(_ item: MediaItem) {
        print("📤 [Share] 打开分享界面")
        
        var itemsToShare: [Any] = []
        
        if item.isAudio, let url = item.compressedVideoURL {
            itemsToShare.append(url)
        } else if item.isVideo, let url = item.compressedVideoURL {
            itemsToShare.append(url)
        } else if let data = item.compressedData {
            let fileExtension: String
            switch item.outputImageFormat {
            case .heic:
                fileExtension = "heic"
            case .png:
                fileExtension = "png"
            case .webp:
                fileExtension = "webp"
            default:
                fileExtension = "jpg"
            }
            
            let fileName = "hummingbird_\(Date().timeIntervalSince1970).\(fileExtension)"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                itemsToShare.append(tempURL)
            } catch {
                return
            }
        }
        
        guard !itemsToShare.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        // 设置完成回调
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            Task { @MainActor in
                if completed {
                    withAnimation {
                        self.showingToast = true
                    }
                    print("✅ [Share] 分享成功")
                } else if let error = error {
                    print("❌ [Share] 分享失败: \(error)")
                } else {
                    print("⚠️ [Share] 用户取消分享")
                }
            }
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
}

