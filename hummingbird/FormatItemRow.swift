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
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if item.isVideo, let videoURL = item.compressedVideoURL {
                    // Save video
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                } else if let imageData = item.compressedData {
                    // Save image using data to preserve EXIF metadata
                    // Using PHAssetCreationRequest with addResource preserves all metadata
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: imageData, options: nil)
                    print("[FormatItemRow] 保存图片，大小: \(imageData.count) bytes，格式: \(item.outputImageFormat?.rawValue ?? "unknown")")
                }
            }
            await showToast("Saved to Photos")
        } catch {
            await showToast("Save failed: \(error.localizedDescription)")
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
