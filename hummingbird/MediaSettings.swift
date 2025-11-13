//
//  MediaSettings.swift
//  hummingbird
//
//  Media processing settings and models
//

import Foundation
import SwiftUI
import Combine

// MARK: - Resize Mode
enum ResizeMode: String, CaseIterable, Identifiable {
    case cover = "Cover"
    case fit = "Fit"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .cover:
            return "Scale proportionally to fill target size, may crop excess"
        case .fit:
            return "Scale proportionally to fit target size, keep complete content, output actual scaled size"
        }
    }
}

// MARK: - Image Resolution
enum ImageResolution: String, CaseIterable, Identifiable {
    case wallpaper4K = "3840×2160 (4K Landscape)"
    case wallpaper4KPortrait = "2160×3840 (4K Portrait)"
    case wallpaper2K = "2560×1440 (2K Landscape)"
    case wallpaper2KPortrait = "1440×2560 (2K Portrait)"
    case wallpaperHD = "1920×1080 (HD Landscape)"
    case phoneWallpaper = "1080×1920 (HD Portrait)"
    case videoCover720p = "1280×720 (720p Landscape)"
    case videoCover720pPortrait = "720×1280 (720p Portrait)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var size: (width: Int, height: Int)? {
        switch self {
        case .wallpaper4K: return (3840, 2160)
        case .wallpaper4KPortrait: return (2160, 3840)
        case .wallpaper2K: return (2560, 1440)
        case .wallpaper2KPortrait: return (1440, 2560)
        case .wallpaperHD: return (1920, 1080)
        case .videoCover720p: return (1280, 720)
        case .videoCover720pPortrait: return (720, 1280)
        case .phoneWallpaper: return (1080, 1920)
        case .custom: return nil
        }
    }
}

// MARK: - Video Codec
enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264 (Better Compatibility)"
    case h265 = "H.265/HEVC (Higher Compression)"
    
    var id: String { rawValue }
    
    var ffmpegCodec: String {
        switch self {
        case .h264: return "h264_videotoolbox"  // Use iOS hardware encoder
        case .h265: return "hevc_videotoolbox"  // Use iOS hardware encoder
        }
    }
    
    var description: String {
        switch self {
        case .h264: return "Hardware encoding, best compatibility"
        case .h265: return "Hardware encoding, smaller file size"
        }
    }
}

// MARK: - Video Quality Preset
enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case ultrafast = "Ultra Fast (Lower Quality)"
    case superfast = "Super Fast (Fair Quality)"
    case veryfast = "Very Fast (Medium Quality)"
    case faster = "Faster (Good Quality)"
    case fast = "Fast (Better Quality)"
    case medium = "Medium (Balanced)"
    case slow = "Slow (Very Good Quality)"
    case slower = "Slower (Excellent Quality)"
    case veryslow = "Very Slow (Best Quality)"
    
    var id: String { rawValue }
    
    var ffmpegPreset: String {
        switch self {
        case .ultrafast: return "ultrafast"
        case .superfast: return "superfast"
        case .veryfast: return "veryfast"
        case .faster: return "faster"
        case .fast: return "fast"
        case .medium: return "medium"
        case .slow: return "slow"
        case .slower: return "slower"
        case .veryslow: return "veryslow"
        }
    }
}

// MARK: - CRF Quality Mode
enum CRFQualityMode: String, CaseIterable, Identifiable {
    case veryHigh = "Very High Quality (CRF 18)"
    case high = "High Quality (CRF 23)"
    case medium = "Medium Quality (CRF 28)"
    case low = "Low Quality (CRF 32)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var crfValue: Int? {
        switch self {
        case .veryHigh: return 18
        case .high: return 23
        case .medium: return 28
        case .low: return 32
        case .custom: return nil
        }
    }
}

// MARK: - Frame Rate Mode
enum FrameRateMode: String, CaseIterable, Identifiable {
    case fps23_98 = "23.98 fps (Film)"
    case fps24 = "24 fps"
    case fps25 = "25 fps (PAL)"
    case fps29_97 = "29.97 fps (NTSC)"
    case fps30 = "30 fps"
    case fps60 = "60 fps"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var frameRateValue: Double? {
        switch self {
        case .fps23_98: return 23.98
        case .fps24: return 24.0
        case .fps25: return 25.0
        case .fps29_97: return 29.97
        case .fps30: return 30.0
        case .fps60: return 60.0
        case .custom: return nil
        }
    }
}

// MARK: - Audio Bitrate
enum AudioBitrate: String, CaseIterable, Identifiable {
    case kbps96 = "96 kbps"
    case kbps128 = "128 kbps"
    case kbps192 = "192 kbps"
    case kbps256 = "256 kbps"
    case kbps320 = "320 kbps"
    
    var id: String { rawValue }
    
    var bitrateValue: Int {
        switch self {
        case .kbps96: return 96
        case .kbps128: return 128
        case .kbps192: return 192
        case .kbps256: return 256
        case .kbps320: return 320
        }
    }
}

// MARK: - Audio Sample Rate
enum AudioSampleRate: String, CaseIterable, Identifiable {
    case hz44100 = "44.1 kHz"
    case hz48000 = "48 kHz"
    
    var id: String { rawValue }
    
    var sampleRateValue: Int {
        switch self {
        case .hz44100: return 44100
        case .hz48000: return 48000
        }
    }
}

// MARK: - Audio Channels
enum AudioChannels: String, CaseIterable, Identifiable {
    case mono = "Mono"
    case stereo = "Stereo"
    
    var id: String { rawValue }
    
    var channelCount: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        }
    }
}

// MARK: - Compression Settings
class CompressionSettings: ObservableObject {
    // Image settings
    @Published var heicQuality: Double = 0.85 {
        didSet { UserDefaults.standard.set(heicQuality, forKey: "heicQuality") }
    }
    @Published var jpegQuality: Double = 0.75 {
        didSet { UserDefaults.standard.set(jpegQuality, forKey: "jpegQuality") }
    }
    @Published var webpQuality: Double = 0.80 {
        didSet { UserDefaults.standard.set(webpQuality, forKey: "webpQuality") }
    }
    @Published var preferHEIC: Bool = false {
        didSet { UserDefaults.standard.set(preferHEIC, forKey: "preferHEIC") }
    }
    @Published var targetImageResolution: ImageResolutionTarget = .original {
        didSet { UserDefaults.standard.set(targetImageResolution.rawValue, forKey: "targetImageResolution") }
    }
    @Published var targetImageOrientationMode: OrientationMode = .auto {
        didSet { UserDefaults.standard.set(targetImageOrientationMode.rawValue, forKey: "targetImageOrientationMode") }
    }
    
    // Audio settings
    @Published var audioBitrate: AudioBitrate = .kbps192 {
        didSet { UserDefaults.standard.set(audioBitrate.rawValue, forKey: "audioBitrate") }
    }
    @Published var audioSampleRate: AudioSampleRate = .hz44100 {
        didSet { UserDefaults.standard.set(audioSampleRate.rawValue, forKey: "audioSampleRate") }
    }
    @Published var audioChannels: AudioChannels = .stereo {
        didSet { UserDefaults.standard.set(audioChannels.rawValue, forKey: "audioChannels") }
    }
    
    // Video settings - FFmpeg parameters
    @Published var videoCodec: VideoCodec = .h265 {
        didSet { UserDefaults.standard.set(videoCodec.rawValue, forKey: "videoCodec") }
    }
    @Published var videoQualityPreset: VideoQualityPreset = .medium {
        didSet { UserDefaults.standard.set(videoQualityPreset.rawValue, forKey: "videoQualityPreset") }
    }
    @Published var crfQualityMode: CRFQualityMode = .high {
        didSet { UserDefaults.standard.set(crfQualityMode.rawValue, forKey: "crfQualityMode") }
    }
    @Published var customCRF: Int = 23 {
        didSet { UserDefaults.standard.set(customCRF, forKey: "customCRF") }
    }
    @Published var useHardwareAcceleration: Bool = true {
        didSet { UserDefaults.standard.set(useHardwareAcceleration, forKey: "useHardwareAcceleration") }
    }
    @Published var frameRateMode: FrameRateMode = .fps29_97 {
        didSet { UserDefaults.standard.set(frameRateMode.rawValue, forKey: "frameRateMode") }
    }
    @Published var customFrameRate: Int = 30 {
        didSet { UserDefaults.standard.set(customFrameRate, forKey: "customFrameRate") }
    }
    @Published var targetVideoResolution: VideoResolution = .original {
        didSet { UserDefaults.standard.set(targetVideoResolution.rawValue, forKey: "targetVideoResolution") }
    }
    @Published var targetOrientationMode: VideoOrientationMode = .auto {
        didSet { UserDefaults.standard.set(targetOrientationMode.rawValue, forKey: "targetOrientationMode") }
    }
    
    init() {
        // Load saved settings from UserDefaults
        if UserDefaults.standard.object(forKey: "heicQuality") != nil {
            self.heicQuality = UserDefaults.standard.double(forKey: "heicQuality")
        }
        if UserDefaults.standard.object(forKey: "jpegQuality") != nil {
            self.jpegQuality = UserDefaults.standard.double(forKey: "jpegQuality")
        }
        if UserDefaults.standard.object(forKey: "webpQuality") != nil {
            self.webpQuality = UserDefaults.standard.double(forKey: "webpQuality")
        }
        if UserDefaults.standard.object(forKey: "preferHEIC") != nil {
            self.preferHEIC = UserDefaults.standard.bool(forKey: "preferHEIC")
        }
        if let resolutionRaw = UserDefaults.standard.string(forKey: "targetImageResolution"),
           let resolution = ImageResolutionTarget(rawValue: resolutionRaw) {
            self.targetImageResolution = resolution
        }
        if let orientationRaw = UserDefaults.standard.string(forKey: "targetImageOrientationMode"),
           let orientation = OrientationMode(rawValue: orientationRaw) {
            self.targetImageOrientationMode = orientation
        }
        
        if let codecRaw = UserDefaults.standard.string(forKey: "videoCodec"),
           let codec = VideoCodec(rawValue: codecRaw) {
            self.videoCodec = codec
        }
        if let presetRaw = UserDefaults.standard.string(forKey: "videoQualityPreset"),
           let preset = VideoQualityPreset(rawValue: presetRaw) {
            self.videoQualityPreset = preset
        }
        if let modeRaw = UserDefaults.standard.string(forKey: "crfQualityMode"),
           let mode = CRFQualityMode(rawValue: modeRaw) {
            self.crfQualityMode = mode
        }
        if UserDefaults.standard.object(forKey: "customCRF") != nil {
            self.customCRF = UserDefaults.standard.integer(forKey: "customCRF")
        }
        if UserDefaults.standard.object(forKey: "useHardwareAcceleration") != nil {
            self.useHardwareAcceleration = UserDefaults.standard.bool(forKey: "useHardwareAcceleration")
        }
        if let modeRaw = UserDefaults.standard.string(forKey: "frameRateMode"),
           let mode = FrameRateMode(rawValue: modeRaw) {
            self.frameRateMode = mode
        }
        if UserDefaults.standard.object(forKey: "customFrameRate") != nil {
            self.customFrameRate = UserDefaults.standard.integer(forKey: "customFrameRate")
        }
        if let resolutionRaw = UserDefaults.standard.string(forKey: "targetVideoResolution"),
           let resolution = VideoResolution(rawValue: resolutionRaw) {
            self.targetVideoResolution = resolution
        }
        if let orientationRaw = UserDefaults.standard.string(forKey: "targetOrientationMode"),
           let orientation = VideoOrientationMode(rawValue: orientationRaw) {
            self.targetOrientationMode = orientation
        }
        
        // Load audio settings
        if let bitrateRaw = UserDefaults.standard.string(forKey: "audioBitrate"),
           let bitrate = AudioBitrate(rawValue: bitrateRaw) {
            self.audioBitrate = bitrate
        }
        if let sampleRateRaw = UserDefaults.standard.string(forKey: "audioSampleRate"),
           let sampleRate = AudioSampleRate(rawValue: sampleRateRaw) {
            self.audioSampleRate = sampleRate
        }
        if let channelsRaw = UserDefaults.standard.string(forKey: "audioChannels"),
           let channels = AudioChannels(rawValue: channelsRaw) {
            self.audioChannels = channels
        }
    }
    
    // Get CRF value
    func getCRFValue() -> Int {
        if let crfValue = crfQualityMode.crfValue {
            return crfValue
        }
        return customCRF
    }
    
    // Get target frame rate
    func getTargetFrameRate() -> Double {
        if let frameRate = frameRateMode.frameRateValue {
            return frameRate
        }
        return Double(customFrameRate)
    }
    
    // Generate FFmpeg command parameters
    func generateFFmpegCommand(inputPath: String, outputPath: String, videoSize: CGSize? = nil, originalFrameRate: Double? = nil) -> String {
        var command = ""
        
        // Hardware acceleration (must be before -i)
        if useHardwareAcceleration {
            command += "-hwaccel auto "
        }
        
        // Input file
        command += "-i \"\(inputPath)\""
        
        // Detect output format, M4V container only supports H.264
        let outputExtension = (outputPath as NSString).pathExtension.lowercased()
        let effectiveCodec: VideoCodec
        
        if outputExtension == "m4v" {
            // M4V container doesn't support HEVC, force H.264
            effectiveCodec = .h264
            if videoCodec == .h265 {
                print("⚠️ [FFmpeg] M4V container doesn't support H.265, auto-switching to H.264")
            }
        } else {
            effectiveCodec = videoCodec
        }
        
        // Video codec
        command += " -c:v \(effectiveCodec.ffmpegCodec)"
        
        // Quality preset
        command += " -preset \(videoQualityPreset.ffmpegPreset)"
        
        // CRF quality control (constant quality mode)
        let crfValue = getCRFValue()
        command += " -crf \(crfValue)"
        
        // Resolution scaling - only scale down if target is smaller than original
        if let originalSize = videoSize, let targetSize = targetVideoResolution.size(for: targetOrientationMode, originalSize: originalSize) {
            let originalWidth = originalSize.width
            let originalHeight = originalSize.height
            let targetWidth = targetSize.width
            let targetHeight = targetSize.height
            
            // Detect original orientation
            let originalOrientation = originalWidth >= originalHeight ? "Landscape" : "Portrait"
            let targetOrientation = targetWidth >= targetHeight ? "Landscape" : "Portrait"
            
            print("🎬 [FFmpeg] Original: \(Int(originalWidth))×\(Int(originalHeight)) (\(originalOrientation))")
            print("🎬 [FFmpeg] Target: \(Int(targetWidth))×\(Int(targetHeight)) (\(targetOrientation))")
            print("🎬 [FFmpeg] Orientation Mode: \(targetOrientationMode.rawValue)")
            
            // Only scale if original is larger than target
            if originalWidth > targetWidth || originalHeight > targetHeight {
                // Calculate aspect ratio preserving scale
                let scaleWidth = targetWidth / originalWidth
                let scaleHeight = targetHeight / originalHeight
                let scale = min(scaleWidth, scaleHeight)
                
                let newWidth = Int(originalWidth * scale)
                let newHeight = Int(originalHeight * scale)
                
                // Ensure dimensions are even (required for video encoding)
                let evenWidth = (newWidth / 2) * 2
                let evenHeight = (newHeight / 2) * 2
                
                command += " -vf scale=\(evenWidth):\(evenHeight)"
                print("🎬 [FFmpeg] Scaling video from \(Int(originalWidth))×\(Int(originalHeight)) to \(evenWidth)×\(evenHeight)")
            } else {
                print("🎬 [FFmpeg] Keeping original resolution \(Int(originalWidth))×\(Int(originalHeight)) (target: \(Int(targetWidth))×\(Int(targetHeight)))")
            }
        }
        
        // Frame rate control - only reduce frame rate if target is lower than original
        let targetFPS = getTargetFrameRate()
        if let originalFPS = originalFrameRate, targetFPS < originalFPS {
            command += " -r \(targetFPS)"
            print("🎬 [FFmpeg] Reducing frame rate from \(originalFPS) fps to \(targetFPS) fps")
        } else if let originalFPS = originalFrameRate {
            print("🎬 [FFmpeg] Keeping original frame rate \(originalFPS) fps (target: \(targetFPS) fps)")
        }
        
        // Audio encoding
        command += " -c:a aac -b:a 128k"
        
        // Pixel format - ensure compatibility
        command += " -pix_fmt yuv420p"
        
        // Video tag - for HEVC, add compatibility tag
        if effectiveCodec == .h265 {
            command += " -tag:v hvc1"  // Use hvc1 tag for better compatibility
        }
        
        // Keep metadata and optimize
        command += " -movflags +faststart"
        
        // Output file
        command += " \"\(outputPath)\""
        
        return command
    }
}

// MARK: - Orientation Mode (shared by both Image and Video)
enum OrientationMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case landscape = "Landscape"
    case portrait = "Portrait"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .landscape: return "Landscape"
        case .portrait: return "Portrait"
        }
    }
}

// Alias for backward compatibility
typealias VideoOrientationMode = OrientationMode

// MARK: - Image Resolution
enum ImageResolutionTarget: String, CaseIterable, Identifiable {
    case original = "Original"
    case uhd4k = "4K"
    case uhd2k = "2K"
    case fullHD = "1080p"
    case hd = "720p"
    
    var id: String { rawValue }
    
    // Get size based on orientation
    func size(for orientation: OrientationMode, originalSize: CGSize?) -> CGSize? {
        // If original, return nil (no scaling)
        if self == .original {
            return nil
        }
        
        // Determine target orientation
        let targetOrientation: OrientationMode
        if orientation == .auto {
            // Auto: detect from original image
            if let original = originalSize {
                targetOrientation = original.width >= original.height ? .landscape : .portrait
            } else {
                targetOrientation = .landscape // Default to landscape if unknown
            }
        } else {
            targetOrientation = orientation
        }
        
        // Get base size (landscape)
        let baseSize: CGSize
        switch self {
        case .original: return nil
        case .uhd4k: baseSize = CGSize(width: 3840, height: 2160)
        case .uhd2k: baseSize = CGSize(width: 2560, height: 1440)
        case .fullHD: baseSize = CGSize(width: 1920, height: 1080)
        case .hd: baseSize = CGSize(width: 1280, height: 720)
        }
        
        // Swap dimensions for portrait
        if targetOrientation == .portrait {
            return CGSize(width: baseSize.height, height: baseSize.width)
        } else {
            return baseSize
        }
    }
    
    var displayName: String {
        switch self {
        case .original: return "Original"
        case .uhd4k: return "4K (3840×2160)"
        case .uhd2k: return "2K (2560×1440)"
        case .fullHD: return "1080p (1920×1080)"
        case .hd: return "720p (1280×720)"
        }
    }
}

// MARK: - Video Resolution
enum VideoResolution: String, CaseIterable, Identifiable {
    case original = "Original"
    case uhd4k = "4K"
    case uhd2k = "2K"
    case fullHD = "1080p"
    case hd = "720p"
    
    var id: String { rawValue }
    
    // Get size based on orientation
    func size(for orientation: OrientationMode, originalSize: CGSize?) -> CGSize? {
        // If original, return nil (no scaling)
        if self == .original {
            return nil
        }
        
        // Determine target orientation
        let targetOrientation: VideoOrientationMode
        if orientation == .auto {
            // Auto: detect from original video
            if let original = originalSize {
                targetOrientation = original.width >= original.height ? .landscape : .portrait
            } else {
                targetOrientation = .landscape // Default to landscape if unknown
            }
        } else {
            targetOrientation = orientation
        }
        
        // Get base size (landscape)
        let baseSize: CGSize
        switch self {
        case .original: return nil
        case .uhd4k: baseSize = CGSize(width: 3840, height: 2160)
        case .uhd2k: baseSize = CGSize(width: 2560, height: 1440)
        case .fullHD: baseSize = CGSize(width: 1920, height: 1080)
        case .hd: baseSize = CGSize(width: 1280, height: 720)
        }
        
        // Swap dimensions for portrait
        if targetOrientation == .portrait {
            return CGSize(width: baseSize.height, height: baseSize.width)
        } else {
            return baseSize
        }
    }
    
    var displayName: String {
        switch self {
        case .original: return "Original"
        case .uhd4k: return "4K (3840×2160)"
        case .uhd2k: return "2K (2560×1440)"
        case .fullHD: return "1080p (1920×1080)"
        case .hd: return "720p (1280×720)"
        }
    }
}

// MARK: - Resolution Settings
class ResolutionSettings: ObservableObject {
    @Published var targetResolution: ImageResolution = .wallpaperHD {
        didSet { UserDefaults.standard.set(targetResolution.rawValue, forKey: "targetResolution") }
    }
    @Published var customWidth: Int = 1920 {
        didSet { UserDefaults.standard.set(customWidth, forKey: "customWidth") }
    }
    @Published var customHeight: Int = 1080 {
        didSet { UserDefaults.standard.set(customHeight, forKey: "customHeight") }
    }
    @Published var resizeMode: ResizeMode = .cover {
        didSet { UserDefaults.standard.set(resizeMode.rawValue, forKey: "resizeMode") }
    }
    
    init() {
        // Load saved settings from UserDefaults
        if let resolutionRaw = UserDefaults.standard.string(forKey: "targetResolution"),
           let resolution = ImageResolution(rawValue: resolutionRaw) {
            self.targetResolution = resolution
        }
        if UserDefaults.standard.object(forKey: "customWidth") != nil {
            self.customWidth = UserDefaults.standard.integer(forKey: "customWidth")
        }
        if UserDefaults.standard.object(forKey: "customHeight") != nil {
            self.customHeight = UserDefaults.standard.integer(forKey: "customHeight")
        }
        if let modeRaw = UserDefaults.standard.string(forKey: "resizeMode"),
           let mode = ResizeMode(rawValue: modeRaw) {
            self.resizeMode = mode
        }
    }
}

// MARK: - Format Conversion Settings
class FormatSettings: ObservableObject {
    @Published var targetImageFormat: ImageFormat = .jpeg {
        didSet { UserDefaults.standard.set(targetImageFormat.rawValue, forKey: "targetImageFormat") }
    }
    @Published var targetVideoFormat: String = "mp4" {
        didSet { UserDefaults.standard.set(targetVideoFormat, forKey: "targetVideoFormat") }
    }
    @Published var useHEVC: Bool = true {
        didSet { UserDefaults.standard.set(useHEVC, forKey: "useHEVC") }
    }
    
    @Published var preserveExif: Bool = true {
        didSet { UserDefaults.standard.set(preserveExif, forKey: "preserveExif") }
    }
    
    init() {
        // Load saved settings from UserDefaults
        if let formatRaw = UserDefaults.standard.string(forKey: "targetImageFormat"),
           let format = ImageFormat(rawValue: formatRaw) {
            self.targetImageFormat = format
        }
        if let videoFormat = UserDefaults.standard.string(forKey: "targetVideoFormat") {
            self.targetVideoFormat = videoFormat
        }
        if UserDefaults.standard.object(forKey: "useHEVC") != nil {
            self.useHEVC = UserDefaults.standard.bool(forKey: "useHEVC")
        }
        if UserDefaults.standard.object(forKey: "preserveExif") != nil {
            self.preserveExif = UserDefaults.standard.bool(forKey: "preserveExif")
        }
    }
}
