//
//  ResolutionItemRow.swift
//  hummingbird
//
//  修改分辨率功能的媒体项行视图
//

import SwiftUI
import Photos

struct ResolutionItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // 预览图
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: item.isVideo ? "video.circle.fill" : "photo.circle.fill")
                            .foregroundStyle(item.isVideo ? .blue : .green)
                        Text(item.isVideo ? "视频" : "图片")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        // 文件扩展名
                        if !item.fileExtension.isEmpty {
                            Text("·")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(item.fileExtension.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Spacer()
                        
                        // 状态标识
                        statusBadge
                    }
                    
                    // 分辨率信息
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("分辨率: \(item.formatResolution(item.originalResolution)) → \(item.formatResolution(item.compressedResolution))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("大小: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // 显示视频时长（仅视频）
                            if item.isVideo {
                                Text("时长: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            if let resolution = item.originalResolution {
                                Text("分辨率: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                    
                    // 进度条
                    if item.status == .processing {
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
                Button(action: { saveToPhotos(item) }) {
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
        .toast(isShowing: $showingToast, message: "保存成功")
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .loading:
            HStack(spacing: 3) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("加载中")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .pending:
            HStack(spacing: 3) {
                Image(systemName: "clock")
                Text("等待中")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case .compressing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("压缩中")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .processing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("处理中")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .completed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                Text("完成")
            }
            .font(.caption)
            .foregroundStyle(.green)
            .lineLimit(1)
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "xmark.circle.fill")
                Text("失败")
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
                    if item.isVideo, let url = item.compressedVideoURL {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else if let data = item.compressedData {
                        // 根据输出格式确定文件扩展名（支持更多格式）
                        let fileExtension: String
                        switch item.outputImageFormat {
                        case .heic:
                            fileExtension = "heic"
                        case .png:
                            fileExtension = "png"
                        case .webp:
                            fileExtension = "webp"
                        case .jpeg:
                            fileExtension = "jpg"
                        default:
                            fileExtension = "jpg"
                        }
                        
                        // 将调整后的数据写入临时文件
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("resized_\(UUID().uuidString).\(fileExtension)")
                        try? data.write(to: tempURL)
                        
                        // 使用文件 URL 保存，保持原始数据
                        let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                        
                        // 清理临时文件（延迟执行，确保保存完成）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            try? FileManager.default.removeItem(at: tempURL)
                        }
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
}
