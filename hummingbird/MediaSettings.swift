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

// MARK: - Video Resolution
enum VideoResolution: String, CaseIterable, Identifiable {
    case uhd4k = "4K (3840×2160)"
    case fullHD = "1080p (1920×1080)"
    case hd = "720p (1280×720)"
    case sd = "480p (854×480)"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var size: CGSize? {
        switch self {
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .hd: return CGSize(width: 1280, height: 720)
        case .sd: return CGSize(width: 854, height: 480)
        case .custom: return nil
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
