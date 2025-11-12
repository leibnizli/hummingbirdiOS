//
//  FormatItemRow.swift
//  hummingbird
//
//  Format conversion list item
//

import SwiftUI
import Photos

struct FormatItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
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
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Information area
                VStack(alignment: .leading, spacing: 4) {
                    // File type and format
                    HStack(spacing: 6) {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if item.status == .completed {
                            // Show format changes
                            let originalFormatText = item.originalImageFormat?.rawValue.uppercased() ?? (item.isVideo ? item.fileExtension.uppercased() : "")
                            let outputFormatText = item.outputImageFormat?.rawValue.uppercased() ?? item.outputVideoFormat?.uppercased() ?? ""
                            
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
                            if let originalFormat = item.originalImageFormat {
                                Text(originalFormat.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if item.isVideo {
                                Text(item.fileExtension.uppercased())
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
                            // Show video duration and codec (video only)
                            if item.isVideo {
                                Text("Duration: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Show codec change
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
                            // Show video duration and codec (video only)
                            if item.isVideo {
                                Text("Duration: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Show codec
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
            
            // Save button
            if item.status == .completed {
                Button(action: { 
                    Task { await saveToPhotos() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.arrow.down")
                            .font(.subheadline)
                        Text("Save to Photos")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
        .toast(isShowing: $showingToast, message: toastMessage)
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
