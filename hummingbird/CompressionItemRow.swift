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
                        
                        // 文件格式
                        if item.status == .completed {
                            let originalFormat = item.originalImageFormat?.rawValue.uppercased() ?? (item.isVideo ? item.fileExtension.uppercased() : "")
                            let outputFormat = item.outputImageFormat?.rawValue.uppercased() ?? item.outputVideoFormat?.uppercased() ?? ""
                            
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
                        }
                        
                        Spacer()
                        
                        // 状态标识
                        statusBadge
                    }
                    
                    // 文件大小和压缩信息
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Size: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let resolution = item.originalResolution {
                                Text("Resolution: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // 显示视频时长、帧率和编码（仅视频）
                            if item.isVideo {
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
                            if let resolution = item.originalResolution {
                                Text("Resolution: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            // 显示视频时长、帧率和编码（仅视频）
                            if item.isVideo {
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
                Button(action: { saveToPhotos(item) }) {
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
        .toast(isShowing: $showingToast, message: "Saved Successfully")
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
                    if item.isVideo, let url = item.compressedVideoURL {
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
                        // 根据输出格式确定文件扩展名
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
                        
                        // 将压缩后的数据写入临时文件
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("compressed_\(UUID().uuidString).\(fileExtension)")
                        try? data.write(to: tempURL)
                        
                        // 使用文件 URL 保存，保持原始压缩数据
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
