//
//  FormatItemRow.swift
//  hummingbird
//
//  Format conversion list item
//

import SwiftUI
import Photos
import AVFoundation

struct FormatItemRow: View {
    @ObservedObject var item: MediaItem
    @StateObject private var audioPlayer = AudioPlayerManager.shared
    @State private var showingToast = false
    @State private var toastMessage = ""
    
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
                    // Thumbnail
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
                            // 优先使用转换后的音频，如果没有则使用原始音频
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
                    
                    // Information area
                    VStack(alignment: .leading, spacing: 4) {
                        // File type and format
                        HStack(spacing: 6) {
                            Image(systemName: item.isAudio ? "music.note" : (item.isVideo ? "video.fill" : "photo.fill"))
                                .font(.caption)
                                .foregroundStyle(item.isAudio ? .purple : .secondary)
                            
                            if item.status == .completed {
                                // Show format changes
                                // 根据文件类型获取原始格式
                                let originalFormatText: String = {
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
                                let outputFormatText: String = {
                                    if item.isImage {
                                        return item.outputImageFormat?.rawValue.uppercased() ?? ""
                                    } else if item.isVideo {
                                        return item.outputVideoFormat?.uppercased() ?? ""
                                    } else if item.isAudio {
                                        return item.outputAudioFormat?.rawValue.uppercased() ?? ""
                                    }
                                    return ""
                                }()
                                
                                if !originalFormatText.isEmpty {
                                    if outputFormatText.isEmpty || originalFormatText == outputFormatText {
                                        // If format hasn't changed, only show original format
                                        Text(originalFormatText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        // If format has changed, show before and after formats
                                        Text(originalFormatText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(outputFormatText)
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            } else {
                                // When not completed, only show original format
                                let originalFormatText: String = {
                                    if item.isImage {
                                        return item.originalImageFormat?.rawValue.uppercased() ?? item.fileExtension.uppercased()
                                    } else if item.isVideo {
                                        return item.fileExtension.uppercased()
                                    } else if item.isAudio {
                                        return item.fileExtension.uppercased()
                                    }
                                    return ""
                                }()
                                
                                if !originalFormatText.isEmpty {
                                    Text(originalFormatText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Size information
                        if item.status == .completed {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Size: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    let diff = item.compressedSize - item.originalSize
                                    if diff > 0 {
                                        Text("(+\(item.formatBytes(diff)))")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    } else if diff < 0 {
                                        Text("(\(item.formatBytes(diff)))")
                                            .font(.caption)
                                            .foregroundStyle(.green)
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
                                            Text("Bitrate: Unknown → \(item.formatAudioBitrate(compressedBitrate))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
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
                                // 显示视频参数（仅视频）
                                else if item.isVideo {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示分辨率变化
                                    if let originalRes = item.originalResolution, let compressedRes = item.compressedResolution {
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
                                    
                                    // 显示帧率变化
                                    if let originalFPS = item.frameRate, let compressedFPS = item.compressedFrameRate {
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
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Size: \(item.formatBytes(item.originalSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
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
                                // 显示视频参数（仅视频）
                                else if item.isVideo {
                                    Text("Duration: \(item.formatDuration(item.duration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示分辨率
                                    if let resolution = item.originalResolution {
                                        Text("Resolution: \(item.formatResolution(resolution))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // 显示帧率
                                    Text("Frame Rate: \(item.formatFrameRate(item.frameRate))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    // 显示编码
                                    if let codec = item.videoCodec {
                                        Text("Codec: \(codec)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Status information
                        statusView
                    }
                }
                
                // Save buttons
                if item.status == .completed {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            if !item.isAudio {
                                Button(action: {
                                    Task { await saveToPhotos() }
                                }) {
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
                            
                            Button(action: {
                                Task { await saveToICloud() }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .font(.caption)
                                    Text("iCloud")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                Task { await shareFile() }
                            }) {
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
                    }.padding(.vertical, 8)
                }
                    
            }
            .padding(.vertical, 8)
            .toast(isShowing: $showingToast, message: toastMessage)
        }
    }
    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
        case .pending:
            Text("Pending conversion")
                .font(.caption)
                .foregroundStyle(.secondary)
            
        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Converting \(Int(item.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Conversion complete")
                    .foregroundStyle(.green)
            }
            .font(.caption)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(item.errorMessage ?? "Conversion failed")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            
        case .compressing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Processing \(Int(item.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private func saveToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            await showToast("Photo library permission required")
            return
        }
        
        // 如果是视频，先在外部处理导出
        var videoURLToSave: URL?
        
        if item.isVideo, let videoURL = item.compressedVideoURL {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: videoURL.path) else {
                print("❌ [FormatItemRow] 视频文件不存在: \(videoURL.path)")
                await showToast("Video file not found")
                return
            }
            
            print("[FormatItemRow] 保存视频: \(videoURL.path)")
            
            // 检查视频编码和容器
            let asset = AVURLAsset(url: videoURL)
            var codecInfo = "Unknown"
            
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let formatDescriptions = videoTrack.formatDescriptions as! [CMFormatDescription]
                if let formatDescription = formatDescriptions.first {
                    let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    let isHEVC = (codecType == kCMVideoCodecType_HEVC || codecType == kCMVideoCodecType_HEVCWithAlpha)
                    let isH264 = (codecType == kCMVideoCodecType_H264)
                    codecInfo = isHEVC ? "HEVC" : (isH264 ? "H.264" : "Other")
                }
            }
            
            let containerType = videoURL.pathExtension.lowercased()
            print("[FormatItemRow] 视频信息: 编码=\(codecInfo), 容器=\(containerType)")
            
            // 确定输出格式和文件类型
            let outputExtension: String
            let outputFileType: AVFileType
            
            switch containerType {
            case "m4v":
                outputExtension = "m4v"
                outputFileType = .m4v
            case "mov":
                outputExtension = "mov"
                outputFileType = .mov
            default:
                outputExtension = "mp4"
                outputFileType = .mp4
            }
            
            // 使用 AVAssetExportSession 重新导出为相册兼容格式
            let compatibleURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("save_\(UUID().uuidString).\(outputExtension)")
            
            print("[FormatItemRow] 使用 AVAssetExportSession 导出兼容格式: \(outputExtension)")
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                print("❌ [FormatItemRow] 无法创建导出会话")
                await showToast("Failed to create export session")
                return
            }
            
            exportSession.outputURL = compatibleURL
            exportSession.outputFileType = outputFileType
            exportSession.shouldOptimizeForNetworkUse = true
            
            // 异步等待导出完成
            await exportSession.export()
            
            if exportSession.status == .completed {
                // 验证导出的文件
                guard FileManager.default.fileExists(atPath: compatibleURL.path) else {
                    print("❌ [FormatItemRow] 导出的文件不存在")
                    await showToast("Export failed")
                    return
                }
                
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: compatibleURL.path)[.size] as? Int) ?? 0
                print("✅ [FormatItemRow] 导出成功，文件大小: \(fileSize) bytes")
                videoURLToSave = compatibleURL
            } else {
                print("❌ [FormatItemRow] 导出失败: \(exportSession.error?.localizedDescription ?? "未知错误")")
                // 如果导出失败，尝试直接保存原文件
                print("⚠️ [FormatItemRow] 尝试直接保存原文件")
                videoURLToSave = videoURL
            }
        }
        
        // 现在执行保存操作
        do {
            if let videoURL = videoURLToSave {
                print("✅ [FormatItemRow] 开始保存视频到相册: \(videoURL.path)")
                
                // 使用最简单的方式：PHPhotoLibrary.shared().performChanges
                // 直接使用 PHAssetChangeRequest.creationRequestForAssetFromVideo
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }
                
                await showToast("Saved to Photos")
                print("✅ [FormatItemRow] 保存成功")
                
                // 清理临时文件
                if videoURL != item.compressedVideoURL {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        try? FileManager.default.removeItem(at: videoURL)
                    }
                }
            } else if let imageData = item.compressedData {
                // Save image using data to preserve EXIF metadata
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: imageData, options: nil)
                    print("[FormatItemRow] 保存图片，大小: \(imageData.count) bytes，格式: \(item.outputImageFormat?.rawValue ?? "unknown")")
                }
                
                await showToast("Saved to Photos")
                print("✅ [FormatItemRow] 保存成功")
            }
        } catch {
            print("❌ [FormatItemRow] 保存失败: \(error.localizedDescription)")
            print("❌ [FormatItemRow] 错误详情: \(error)")
            
            // 如果保存失败，尝试使用系统分享功能
            if let videoURL = videoURLToSave {
                await showToast("Trying alternative save method...")
                await saveVideoUsingShareSheet(videoURL)
            } else {
                await showToast("Save failed: \(error.localizedDescription)")
            }
        }
    }
    
    // 备用方案：使用系统分享功能保存
    @MainActor
    private func saveVideoUsingShareSheet(_ url: URL) async {
        // 这个方法可以让用户手动选择保存到相册
        print("[FormatItemRow] 使用分享功能保存视频")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await showToast("Cannot access view controller")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // iPad 需要设置 popover
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
    
    private func saveToICloud() async {
        print("🔵 [iCloud] 使用文档选择器保存")
        
        await MainActor.run {
            // 准备临时文件
            var fileURL: URL?
            
            if item.isAudio, let audioURL = item.compressedVideoURL {
                fileURL = audioURL
            } else if item.isVideo, let videoURL = item.compressedVideoURL {
                fileURL = videoURL
            } else if let imageData = item.compressedData {
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
                    try imageData.write(to: tempURL)
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
                        await self.showToast("Saved successfully")
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
    
    private func shareFile() async {
        print("📤 [Share] 打开分享界面")
        
        await MainActor.run {
            var itemsToShare: [Any] = []
            
            if item.isAudio, let audioURL = item.compressedVideoURL {
                itemsToShare.append(audioURL)
            } else if item.isVideo, let videoURL = item.compressedVideoURL {
                itemsToShare.append(videoURL)
            } else if let imageData = item.compressedData {
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
                    try imageData.write(to: tempURL)
                    itemsToShare.append(tempURL)
                } catch {
                    print("❌ [Share] 创建临时文件失败")
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
                        await self.showToast("Shared successfully")
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
    
    @MainActor
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation {
            showingToast = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                showingToast = false
            }
        }
    }
}
