//
//  MediaItem.swift
//  hummingbird
//
//  Media file item model
//

import Foundation
import SwiftUI
import PhotosUI
import Combine
import AVFoundation

enum CompressionStatus {
    case loading      // Loading
    case pending      // Pending
    case compressing  // Compressing
    case processing   // Processing (for resolution adjustment)
    case completed    // Completed
    case failed       // Failed
}

@MainActor
class MediaItem: Identifiable, ObservableObject {
    let id = UUID()
    let pickerItem: PhotosPickerItem?
    let isVideo: Bool
    
    @Published var originalData: Data?
    @Published var originalSize: Int = 0
    @Published var compressedData: Data?
    @Published var compressedSize: Int = 0
    @Published var status: CompressionStatus = .pending
    @Published var progress: Float = 0
    @Published var errorMessage: String?
    @Published var thumbnailImage: UIImage?
    @Published var fileExtension: String = ""
    
    // Resolution information
    @Published var originalResolution: CGSize?
    @Published var compressedResolution: CGSize?
    
    // Video duration (seconds, video only)
    @Published var duration: Double?
    
    // Video frame rate (fps, video only)
    @Published var frameRate: Double?
    
    // Compressed video frame rate (fps, video only)
    @Published var compressedFrameRate: Double?
    
    // Video codec (e.g., "HEVC", "H.264")
    @Published var videoCodec: String?
    
    // Compressed video codec
    @Published var compressedVideoCodec: String?
    
    // Original image format (detected from PhotosPickerItem)
    var originalImageFormat: ImageFormat?
    
    // Output image format (compressed format)
    var outputImageFormat: ImageFormat?
    
    // Output video format (converted format)
    var outputVideoFormat: String?
    
    // Temporary file URL (for video)
    var sourceVideoURL: URL?
    var compressedVideoURL: URL?
    
    init(pickerItem: PhotosPickerItem?, isVideo: Bool) {
        self.pickerItem = pickerItem
        self.isVideo = isVideo
        self.status = pickerItem != nil ? .loading : .pending  // If imported from file, set to pending status directly
    }
    
    // Calculate compression ratio (percentage reduced)
    var compressionRatio: Double {
        guard originalSize > 0, compressedSize > 0 else { return 0 }
        return Double(originalSize - compressedSize) / Double(originalSize)
    }
    
    // Calculate size reduction
    var savedSize: Int {
        return originalSize - compressedSize
    }
    
    // Format byte size
    func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.3f KB", kb) }
        return String(format: "%.3f MB", kb / 1024.0)
    }
    
    // Format resolution
    func formatResolution(_ size: CGSize?) -> String {
        guard let size = size else { return "Unknown" }
        return "\(Int(size.width))×\(Int(size.height))"
    }
    
    // Format duration
    func formatDuration(_ duration: Double?) -> String {
        guard let duration = duration, duration > 0 else { return "Unknown" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Format frame rate
    func formatFrameRate(_ frameRate: Double?) -> String {
        guard let frameRate = frameRate, frameRate > 0 else { return "Unknown" }
        // 如果是整数帧率，不显示小数
        if frameRate == floor(frameRate) {
            return String(format: "%.0f fps", frameRate)
        }
        // 否则显示两位小数
        return String(format: "%.2f fps", frameRate)
    }
    
    // Detect video codec from URL
    static func detectVideoCodec(from url: URL) -> String? {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let formatDescriptions = videoTrack.formatDescriptions as! [CMFormatDescription]
        guard let formatDescription = formatDescriptions.first else {
            return nil
        }
        
        let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
        
        // Check codec type
        if codecType == kCMVideoCodecType_HEVC || codecType == kCMVideoCodecType_HEVCWithAlpha {
            return "HEVC"
        } else if codecType == kCMVideoCodecType_H264 {
            return "H.264"
        } else if codecType == kCMVideoCodecType_MPEG4Video {
            return "MPEG-4"
        } else if codecType == kCMVideoCodecType_VP9 {
            return "VP9"
        } else {
            // Return codec as FourCC string
            let fourCC = String(format: "%c%c%c%c",
                              (codecType >> 24) & 0xff,
                              (codecType >> 16) & 0xff,
                              (codecType >> 8) & 0xff,
                              codecType & 0xff)
            return fourCC
        }
    }
    
    // Lazy load video data (only load when needed)
    func loadVideoDataIfNeeded() async -> Data? {
        if let existingData = originalData {
            return existingData
        }
        
        guard isVideo, let sourceURL = sourceVideoURL else {
            return nil
        }
        
        // If it's a temporary file, read directly
        if sourceURL.path.contains(NSTemporaryDirectory()) {
            return try? Data(contentsOf: sourceURL)
        }
        
        // If it's a PhotosPickerItem, reload
        if let pickerItem = pickerItem {
            do {
                let data = try await pickerItem.loadTransferable(type: Data.self)
                await MainActor.run {
                    self.originalData = data
                    if let data = data {
                        self.originalSize = data.count
                    }
                }
                return data
            } catch {
                print("Lazy load video data failed: \(error)")
                return nil
            }
        }
        
        return nil
    }
}
