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
        HStack(spacing: 12) {
            // 缩略图
            if let thumbnail = item.thumbnailImage {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        ProgressView()
                    }
            }
            
            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                // 文件类型和格式
                HStack(spacing: 6) {
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let originalFormat = item.originalImageFormat {
                        Text(originalFormat.rawValue.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if item.isVideo {
                        Text(item.fileExtension.uppercased())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if item.status == .completed {
                        if let outputFormat = item.outputImageFormat {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(outputFormat.rawValue.uppercased())
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else if let outputVideoFormat = item.outputVideoFormat {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(outputVideoFormat.uppercased())
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                // 原始大小
                Text("原始: \(item.formatBytes(item.originalSize))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // 转换后大小
                if item.status == .completed {
                    HStack(spacing: 4) {
                        Text("转换后: \(item.formatBytes(item.compressedSize))")
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
                }
                
                // 状态信息
                statusView
            }
            
            Spacer()
            
            // 保存按钮
            if item.status == .completed {
                Button(action: {
                    Task { await saveToPhotos() }
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if showingToast {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch item.status {
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
