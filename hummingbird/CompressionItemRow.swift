//
//  CompressionItemRow.swift
//  hummingbird
//
//  压缩功能的媒体项行视图
//

import SwiftUI
import Photos

struct CompressionItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingSaveAlert = false
    
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
                        
                        Spacer()
                        
                        // 状态标识
                        statusBadge
                    }
                    
                    // 文件大小和压缩信息
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("原始: \(item.formatBytes(item.originalSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("压缩后: \(item.formatBytes(item.compressedSize))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let resolution = item.originalResolution {
                                HStack {
                                    Text("分辨率: \(item.formatResolution(resolution))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            
                            HStack {
                                Text("减少: \(item.formatBytes(item.savedSize))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("压缩率: \(String(format: "%.1f%%", item.compressionRatio * 100))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("大小: \(item.formatBytes(item.originalSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let resolution = item.originalResolution {
                                Text("分辨率: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                Button(action: { saveToPhotos(item) }) {
                    Label("保存到相册", systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .alert("保存成功", isPresented: $showingSaveAlert) {
                    Button("确定", role: .cancel) { }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Label("等待中", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        case .compressing:
            Label("压缩中", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.blue)
        case .processing:
            Label("处理中", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption)
                .foregroundStyle(.blue)
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
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
                    } else if let data = item.compressedData, let image = UIImage(data: data) {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                }
                await MainActor.run {
                    showingSaveAlert = true
                }
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }
}
