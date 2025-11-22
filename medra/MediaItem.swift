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
    @Published var infoMessage: String?
    @Published var thumbnailImage: UIImage?
    @Published var fileExtension: String = ""
    
    // Processing time tracking (for estimated time remaining)
    @Published var processingStartTime: Date?
    
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

    // Video pixel format and bit depth
    @Published var videoPixelFormat: String?
    @Published var videoBitDepth: Int?
    
    // Video bitrate (kbps)
    @Published var videoBitrate: Int?
    @Published var compressedVideoBitrate: Int?
    
    // Audio metadata (for audio files)
    @Published var audioBitrate: Int?  // kbps
    @Published var audioSampleRate: Int?  // Hz
    @Published var audioChannels: Int?  // 1=mono, 2=stereo
    
    // Compressed audio metadata
    @Published var compressedAudioBitrate: Int?
    @Published var compressedAudioSampleRate: Int?
    @Published var compressedAudioChannels: Int?
    
    // Is this an audio file?
    var isAudio: Bool {
        let audioExtensions = ["mp3", "m4a", "aac", "wav", "flac", "ogg", "opus"]
        return audioExtensions.contains(fileExtension.lowercased())
    }
    
    // Is this an image file?
    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff", "tif", "avif"]
        return imageExtensions.contains(fileExtension.lowercased())
    }
    
    // Original image format (detected from PhotosPickerItem)
    var originalImageFormat: ImageFormat?
    
    // Output image format (compressed format)
    var outputImageFormat: ImageFormat?
    
    // Output video format (converted format)
    var outputVideoFormat: String?
    
    // Output audio format (compressed format)
    var outputAudioFormat: AudioFormat?
    
    // WebP animation info
    @Published var isAnimatedWebP: Bool = false
    @Published var webpFrameCount: Int = 0
    @Published var preservedAnimation: Bool = false  // 是否保留了动画
    @Published var isAnimatedAVIF: Bool = false
    @Published var avifFrameCount: Int = 0
    @Published var isAnimatedGIF: Bool = false
    @Published var gifFrameCount: Int = 0
    
    // PNG compression metadata (actual applied engine details)
    @Published var pngCompressionReport: PNGCompressionReport?
    
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
    
    // Calculate total frames (for videos)
    var totalFrames: Int? {
        guard let duration = duration, let frameRate = frameRate, duration > 0, frameRate > 0 else {
            return nil
        }
        return Int(duration * frameRate)
    }
    
    // Format total frames
    func formatTotalFrames() -> String {
        guard let frames = totalFrames else { return "Unknown" }
        return "\(frames) frames"
    }
    
    // Calculate estimated time remaining (based on current progress)
    func estimatedTimeRemaining() -> String? {
        guard let startTime = processingStartTime, progress > 0, progress < 1.0 else {
            return nil
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let estimatedTotalTime = elapsedTime / Double(progress)
        let remainingTime = estimatedTotalTime - elapsedTime
        
        // Don't show if less than 1 second remaining
        guard remainingTime > 1 else { return nil }
        
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        
        if minutes > 0 {
            return "~\(minutes)m \(seconds)s remaining"
        } else {
            return "~\(seconds)s remaining"
        }
    }
    
    // Format audio bitrate
    func formatAudioBitrate(_ bitrate: Int?) -> String {
        guard let bitrate = bitrate, bitrate > 0 else { return "Unknown" }
        return "\(bitrate) kbps"
    }
    
    // Format video bitrate
    func formatVideoBitrate(_ bitrate: Int?) -> String {
        guard let bitrate = bitrate, bitrate > 0 else { return "Unknown" }
        if bitrate >= 1000 {
            return String(format: "%.1f Mbps", Double(bitrate) / 1000.0)
        }
        return "\(bitrate) kbps"
    }

    func formatVideoBitDepth(_ bitDepth: Int?) -> String {
        guard let bitDepth = bitDepth, bitDepth > 0 else { return "Unknown" }
        return "\(bitDepth)-bit"
    }

    static func deriveBitDepth(pixelFormat: String?, bitsPerRawSample: Int?) -> Int? {
        if let bits = bitsPerRawSample, bits > 0 {
            return bits
        }
        guard let format = pixelFormat?.lowercased() else {
            return nil
        }

        let patterns: [(String, Int)] = [
            ("p16", 16), ("p016", 16), ("16le", 16),
            ("p14", 14), ("14le", 14),
            ("p12", 12), ("12le", 12), ("p412", 12),
            ("p10", 10), ("p010", 10), ("p210", 10), ("10le", 10)
        ]

        for (pattern, depth) in patterns {
            if format.contains(pattern) {
                return depth
            }
        }

        if format.contains("nv12") || format.contains("yuv") || format.contains("420") {
            return 8
        }

        return nil
    }
    
    // Format audio sample rate
    func formatAudioSampleRate(_ sampleRate: Int?) -> String {
        guard let sampleRate = sampleRate, sampleRate > 0 else { return "Unknown" }
        let khz = Double(sampleRate) / 1000.0
        return String(format: "%.1f kHz", khz)
    }
    
    // Format audio channels
    func formatAudioChannels(_ channels: Int?) -> String {
        guard let channels = channels else { return "Unknown" }
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(channels) channels"
        }
    }
    
    // Detect video codec from URL (synchronous version)
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
        
        return codecTypeToString(codecType)
    }
    
    // Detect video codec from URL (async version - more reliable)
    static func detectVideoCodecAsync(from url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let videoTrack = tracks.first else {
                return nil
            }
            
            let formatDescriptions = videoTrack.formatDescriptions as! [CMFormatDescription]
            guard let formatDescription = formatDescriptions.first else {
                return nil
            }
            
            let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
            
            let codecString = codecTypeToString(codecType)
            print("🎬 [detectVideoCodecAsync] 检测到编码: \(codecString ?? "Unknown"), FourCC: \(String(format: "0x%08X", codecType))")
            
            return codecString
        } catch {
            print("❌ [detectVideoCodecAsync] 检测失败: \(error)")
            return nil
        }
    }
    
    // Convert codec type to string
    private static func codecTypeToString(_ codecType: CMVideoCodecType) -> String? {
        // 将 FourCC 转换为字符串用于调试
        let fourCCString = String(format: "%c%c%c%c",
                          (codecType >> 24) & 0xff,
                          (codecType >> 16) & 0xff,
                          (codecType >> 8) & 0xff,
                          codecType & 0xff)
        
        // Check codec type using both constants and FourCC codes
        switch codecType {
        // HEVC variants
        case kCMVideoCodecType_HEVC,
             kCMVideoCodecType_HEVCWithAlpha,
             0x68766331, // 'hvc1'
             0x68657631: // 'hev1'
            return "HEVC"
            
        // H.264 variants
        case kCMVideoCodecType_H264,
             0x61766331, // 'avc1'
             0x61766333: // 'avc3'
            return "H.264"
            
        // MPEG-4 Part 2
        case kCMVideoCodecType_MPEG4Video,
             0x6d703476: // 'mp4v'
            return "MPEG-4"
            
        // MPEG-2
        case kCMVideoCodecType_MPEG2Video:
            return "MPEG-2"
            
        // MPEG-1
        case kCMVideoCodecType_MPEG1Video:
            return "MPEG-1"
            
        // VP9
        case kCMVideoCodecType_VP9,
             0x76703039: // 'vp09'
            return "VP9"
            
        // VP8
        case 0x76703038: // 'vp08'
            return "VP8"
            
        // AV1
        case 0x61763031: // 'av01'
            return "AV1"
            
        // DivX/Xvid
        case 0x64697678, // 'divx'
             0x44495633, // 'DIV3'
             0x44585430: // 'DXT0'
            return "DivX"
            
        // Dolby Vision variants
        case 0x64766865: // 'dvhe'
            return "DVHE"
        case 0x64766831: // 'dvh1'
            return "DVH1"
        case 0x64766131: // 'dva1'
            return "DVA1"
        case 0x64766176: // 'dvav'
            return "DVAV"
        case 0x64766863: // 'dvhc'
            return "DVHC"

        // ProRes variants
        case kCMVideoCodecType_AppleProRes422,
             kCMVideoCodecType_AppleProRes4444,
             kCMVideoCodecType_AppleProRes422HQ,
             kCMVideoCodecType_AppleProRes422LT,
             kCMVideoCodecType_AppleProRes422Proxy:
            return "ProRes"
            
        // H.263
        case 0x68323633: // 'h263'
            return "H.263"
            
        default:
            // 返回 FourCC 字符串作为通用标识
            print("ℹ️ [codecTypeToString] 编码: \(fourCCString) (0x\(String(format: "%08X", codecType)))")
            return fourCCString
        }
    }

    static func isDolbyVisionCodec(_ codecIdentifier: String?) -> Bool {
        guard let identifier = codecIdentifier?.lowercased() else { return false }
        return ["dvhe", "dvh1", "dva1", "dvav", "dvhc", "dvhb", "dvmo"].contains { identifier.contains($0) }
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
