//
//  ResolutionItemRow.swift
//  hummingbird
//
//  Media item row view for resolution modification feature
//

import SwiftUI
import Photos

struct ResolutionItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Preview image
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: item.isVideo ? "video.circle.fill" : "photo.circle.fill")
                            .foregroundStyle(item.isVideo ? .blue : .green)
                        
                        // File extension
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
                        
                        Spacer()
                        
                        // Status badge
                        statusBadge
                    }
                    
                    // Resolution information
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolution: \(item.formatResolution(item.originalResolution)) → \(item.formatResolution(item.compressedResolution))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("Size: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
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
                            if let resolution = item.originalResolution {
                                Text("Resolution: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                    
                    // Progress bar
                    if item.status == .processing {
                        ProgressView(value: Double(item.progress))
                            .tint(.blue)
                    }
                    
                    // Error message
                    if let error = item.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }
            
            // Save button
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
        .toast(isShowing: $showingToast, message: "Saved successfully")
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
                print("Photo library permission denied")
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if item.isVideo, let url = item.compressedVideoURL {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else if let data = item.compressedData {
                        // Determine file extension based on output format (support more formats)
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
                        
                        // Write resized data to temporary file
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("resized_\(UUID().uuidString).\(fileExtension)")
                        try? data.write(to: tempURL)
                        
                        // Save using file URL, keep original data
                        let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                        
                        // Clean up temporary file (delayed to ensure save completes)
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
                print("Save failed: \(error.localizedDescription)")
            }
        }
    }
}
