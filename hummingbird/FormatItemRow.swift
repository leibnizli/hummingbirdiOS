//
//  FormatItemRow.swift
//  hummingbird
//
//  格式转换列表项
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
                // 缩略图
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
                
                // 信息区域
                VStack(alignment: .leading, spacing: 4) {
                    // 文件类型和格式
                    HStack(spacing: 6) {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if item.status == .completed {
                            // 显示格式的变化
                            let originalFormatText = item.originalImageFormat?.rawValue.uppercased() ?? (item.isVideo ? item.fileExtension.uppercased() : "")
                            let outputFormatText = item.outputImageFormat?.rawValue.uppercased() ?? item.outputVideoFormat?.uppercased() ?? ""
                            
                            if !originalFormatText.isEmpty {
                                if outputFormatText.isEmpty || originalFormatText == outputFormatText {
                                    // 如果格式没有变化，只显示原始格式
                                    Text(originalFormatText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    // 如果格式有变化，显示转换前后的格式
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
                            // 未处理完成时只显示原始格式
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
                    
                    // 大小信息
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("大小: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
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
                            // 显示视频时长（仅视频）
                            if item.isVideo {
                                Text("时长: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("大小: \(item.formatBytes(item.originalSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // 显示视频时长（仅视频）
                            if item.isVideo {
                                Text("时长: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // 状态信息
                    statusView
                }
            }
            
            // 保存按钮
            if item.status == .completed {
                Button(action: { 
                    Task { await saveToPhotos() }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.badge.arrow.down")
                            .font(.subheadline)
                        Text("保存到相册")
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
                Text("加载中")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
        case .pending:
            Text("等待转换")
                .font(.caption)
                .foregroundStyle(.secondary)
            
        case .processing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("转换中 \(Int(item.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("转换完成")
                    .foregroundStyle(.green)
            }
            .font(.caption)
            
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(item.errorMessage ?? "转换失败")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            
        case .compressing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("处理中 \(Int(item.progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private func saveToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            await showToast("需要相册权限")
            return
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if item.isVideo, let videoURL = item.compressedVideoURL {
                    // 保存视频
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                } else if let imageData = item.compressedData {
                    // 保存图片 - 需要特殊处理 WebP 和 HEIC 格式
                    guard let image = UIImage(data: imageData) else { return }
                    
                    // 检查输出格式，如果是 WebP 或 HEIC，转换为 JPEG 保存
                    // 因为 iOS 相册的 PHAssetChangeRequest 不直接支持这些格式
                    if item.outputImageFormat == .webp || item.outputImageFormat == .heic {
                        // 转换为 JPEG 格式保存（高质量）
                        if let jpegData = image.jpegData(compressionQuality: 0.95) {
                            let request = PHAssetCreationRequest.forAsset()
                            request.addResource(with: .photo, data: jpegData, options: nil)
                        }
                    } else {
                        // PNG 和 JPEG 可以直接保存
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }
            }
            await showToast("已保存到相册")
        } catch {
            await showToast("保存失败: \(error.localizedDescription)")
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
