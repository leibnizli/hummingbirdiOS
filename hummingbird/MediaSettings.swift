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
        case .h264: return "Hardware encoding, best compatibility, supports all input formats"
        case .h265: return "Hardware encoding, smaller file size, supports all input formats"
        }
    }
}

// MARK: - Video Quality Preset
enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case ultrafast = "Ultra Fast (Lower)"
    case superfast = "Super Fast (Fair)"
    case veryfast = "Very Fast (Medium)"
    case faster = "Faster (Good)"
    case fast = "Fast (Better)"
    case medium = "Medium (Balanced)"
    case slow = "Slow (Very Good)"
    case slower = "Slower (Excellent)"
    case veryslow = "Very Slow (Best)"
    
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
    case veryHigh = "Very High (CRF 18)"
    case high = "High (CRF 23)"
    case medium = "Medium (CRF 28)"
    case low = "Low (CRF 32)"
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
    case kbps32 = "32 kbps - Very Low"
    case kbps64 = "64 kbps - Voice/Podcast (Mono)"
    case kbps96 = "96 kbps - Low Music"
    case kbps128 = "128 kbps - Standard MP3"
    case kbps160 = "160 kbps - Good Music"
    case kbps192 = "192 kbps - Very Good"
    case kbps256 = "256 kbps - High Music"
    case kbps320 = "320 kbps - Maximum MP3"
    
    var id: String { rawValue }
    
    var bitrateValue: Int {
        switch self {
        case .kbps32: return 32
        case .kbps64: return 64
        case .kbps96: return 96
        case .kbps128: return 128
        case .kbps160: return 160
        case .kbps192: return 192
        case .kbps256: return 256
        case .kbps320: return 320
        }
    }
    
    var description: String {
        switch self {
        case .kbps32: return "Very Low"
        case .kbps64: return "Voice/Podcast (Mono)"
        case .kbps96: return "Low Music"
        case .kbps128: return "Standard MP3"
        case .kbps160: return "Good Music"
        case .kbps192: return "Very Good (Recommended)"
        case .kbps256: return "High Music"
        case .kbps320: return "Maximum MP3"
        }
    }
}

// MARK: - Audio Sample Rate
enum AudioSampleRate: String, CaseIterable, Identifiable {
    case hz8000 = "8 kHz - Telephone"
    case hz11025 = "11.025 kHz - AM Radio"
    case hz16000 = "16 kHz - Wideband Voice"
    case hz22050 = "22.05 kHz - FM Radio"
    case hz32000 = "32 kHz - Digital Broadcast"
    case hz44100 = "44.1 kHz - CD Standard"
    case hz48000 = "48 kHz - Professional Audio"
    
    var id: String { rawValue }
    
    var sampleRateValue: Int {
        switch self {
        case .hz8000: return 8000
        case .hz11025: return 11025
        case .hz16000: return 16000
        case .hz22050: return 22050
        case .hz32000: return 32000
        case .hz44100: return 44100
        case .hz48000: return 48000
        }
    }
    
    var description: String {
        switch self {
        case .hz8000: return "Telephone"
        case .hz11025: return "AM Radio"
        case .hz16000: return "Wideband Voice (VoIP)"
        case .hz22050: return "FM Radio"
        case .hz32000: return "Digital Broadcast"
        case .hz44100: return "CD Standard (Most Common)"
        case .hz48000: return "Professional Audio/Video"
        }
    }
}

// MARK: - AVIF Speed Preset
enum AVIFSpeedPreset: String, CaseIterable, Identifiable {
    case fast = "Fast"
    case balanced = "Balanced"
    case best = "Best Quality"
    
    var id: String { rawValue }
    
    var cpuUsedValue: Int {
        switch self {
        case .fast: return 8       // Fastest encoding
        case .balanced: return 4   // Recommended default
        case .best: return 0       // Slowest, best quality
        }
    }
    
    var description: String {
        switch self {
        case .fast: return "Faster encoding, slightly lower quality"
        case .balanced: return "Good balance of speed and quality (recommended)"
        case .best: return "Slowest encoding, maximum quality"
        }
    }
}

// MARK: - AVIF Encoder Backend
enum AVIFEncoderBackend: String, CaseIterable, Identifiable {
    case systemImageIO = "System (ImageIO)"
    case ffmpeg = "FFmpeg (libaom-av1)"
    case libavif = "libavif (AOMedia)"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemImageIO: return "System (ImageIO)"
        case .ffmpeg: return "FFmpeg (libaom-av1)"
        case .libavif: return "libavif (Native)"
        }
    }

    var description: String {
        switch self {
        case .systemImageIO:
            return "Use iOS ImageIO AVIF encoder when available (iOS 16+)."
        case .ffmpeg:
            return "Use FFmpeg libaom-av1 encoder via ffmpeg-kit."
        case .libavif:
            return "Use AOMedia libavif C library for encoding."
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

// MARK: - PNG Compression Tool
enum PNGCompressionTool: String, CaseIterable, Identifiable {
    case appleOptimized
    case zopfli
    case pngquant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleOptimized: return "Adaptive (Apple)"
        case .zopfli: return "Zopfli (lossless)"
        case .pngquant: return "pngquant (palette)"
        }
    }

    var description: String {
        switch self {
        case .appleOptimized:
            return "Uses Apple frameworks to re-encode with grayscale/RGB/palette heuristics. No external libraries required."
        case .zopfli:
            return "Runs zopflipng for maximal lossless compression and respects lossy 8-bit/alpha options."
        case .pngquant:
            return "Uses libimagequant color quantization before encoding to PNG. Reduces colors to shrink file size."
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
    @Published var avifQuality: Double = 0.85 {
        didSet { UserDefaults.standard.set(avifQuality, forKey: "avifQuality") }
    }
    @Published var avifSpeedPreset: AVIFSpeedPreset = .balanced {
        didSet { UserDefaults.standard.set(avifSpeedPreset.rawValue, forKey: "avifSpeedPreset") }
    }
    @Published var avifEncoderBackend: AVIFEncoderBackend = .systemImageIO {
        didSet { UserDefaults.standard.set(avifEncoderBackend.rawValue, forKey: "avifEncoderBackend") }
    }
    @Published var preserveAnimatedWebP: Bool = true {
        didSet { UserDefaults.standard.set(preserveAnimatedWebP, forKey: "preserveAnimatedWebP") }
    }
    @Published var preserveAnimatedAVIF: Bool = false {
        didSet { UserDefaults.standard.set(preserveAnimatedAVIF, forKey: "preserveAnimatedAVIF") }
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
    
    // PNG compression settings (zopflipng parameters)
    @Published var pngNumIterations: Int = 3 {
        didSet { UserDefaults.standard.set(pngNumIterations, forKey: "pngNumIterations") }
    }
    @Published var pngNumIterationsLarge: Int = 1 {
        didSet { UserDefaults.standard.set(pngNumIterationsLarge, forKey: "pngNumIterationsLarge") }
    }
    @Published var pngLossyTransparent: Bool = false {
        didSet { UserDefaults.standard.set(pngLossyTransparent, forKey: "pngLossyTransparent") }
    }
    @Published var pngLossy8bit: Bool = false {
        didSet { UserDefaults.standard.set(pngLossy8bit, forKey: "pngLossy8bit") }
    }
    @Published var pngCompressionTool: PNGCompressionTool = .pngquant {
        didSet { UserDefaults.standard.set(pngCompressionTool.rawValue, forKey: "pngCompressionTool") }
    }
    @Published var pngQuantMinQuality: Double = 0.6 {
        didSet {
            let clampedValue = max(0.1, min(pngQuantMinQuality, pngQuantMaxQuality))
            if abs(pngQuantMinQuality - clampedValue) > .ulpOfOne {
                pngQuantMinQuality = clampedValue
                return
            }
            UserDefaults.standard.set(pngQuantMinQuality, forKey: "pngQuantMinQuality")
        }
    }
    @Published var pngQuantMaxQuality: Double = 0.95 {
        didSet {
            let clampedValue = min(1.0, max(pngQuantMaxQuality, pngQuantMinQuality))
            if abs(pngQuantMaxQuality - clampedValue) > .ulpOfOne {
                pngQuantMaxQuality = clampedValue
                return
            }
            UserDefaults.standard.set(pngQuantMaxQuality, forKey: "pngQuantMaxQuality")
        }
    }
    @Published var pngQuantSpeed: Int = 3 {
        didSet {
            let clampedValue = max(1, min(pngQuantSpeed, 10))
            if pngQuantSpeed != clampedValue {
                pngQuantSpeed = clampedValue
                return
            }
            UserDefaults.standard.set(pngQuantSpeed, forKey: "pngQuantSpeed")
        }
    }
    
    // Audio settings
    @Published var audioFormat: AudioFormat = .original {
        didSet { UserDefaults.standard.set(audioFormat.rawValue, forKey: "audioFormat") }
    }
    @Published var audioBitrate: AudioBitrate = .kbps128 {
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
    @Published var useAutoBitrate: Bool = true {
        didSet { UserDefaults.standard.set(useAutoBitrate, forKey: "useAutoBitrate") }
    }
    @Published var customVideoBitrate: Int = 3000 {
        didSet { UserDefaults.standard.set(customVideoBitrate, forKey: "customVideoBitrate") }
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
        if UserDefaults.standard.object(forKey: "avifQuality") != nil {
            self.avifQuality = UserDefaults.standard.double(forKey: "avifQuality")
        }
        if let presetRaw = UserDefaults.standard.string(forKey: "avifSpeedPreset"),
           let preset = AVIFSpeedPreset(rawValue: presetRaw) {
            self.avifSpeedPreset = preset
        }
        if let backendRaw = UserDefaults.standard.string(forKey: "avifEncoderBackend"),
           let backend = AVIFEncoderBackend(rawValue: backendRaw) {
            self.avifEncoderBackend = backend
        }
        if UserDefaults.standard.object(forKey: "preserveAnimatedWebP") != nil {
            self.preserveAnimatedWebP = UserDefaults.standard.bool(forKey: "preserveAnimatedWebP")
        }
        if UserDefaults.standard.object(forKey: "preserveAnimatedAVIF") != nil {
            self.preserveAnimatedAVIF = UserDefaults.standard.bool(forKey: "preserveAnimatedAVIF")
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
        
        if UserDefaults.standard.object(forKey: "pngNumIterations") != nil {
            self.pngNumIterations = UserDefaults.standard.integer(forKey: "pngNumIterations")
        }
        if UserDefaults.standard.object(forKey: "pngNumIterationsLarge") != nil {
            self.pngNumIterationsLarge = UserDefaults.standard.integer(forKey: "pngNumIterationsLarge")
        }
        if UserDefaults.standard.object(forKey: "pngLossyTransparent") != nil {
            self.pngLossyTransparent = UserDefaults.standard.bool(forKey: "pngLossyTransparent")
        }
        if UserDefaults.standard.object(forKey: "pngLossy8bit") != nil {
            self.pngLossy8bit = UserDefaults.standard.bool(forKey: "pngLossy8bit")
        }
        if let toolRaw = UserDefaults.standard.string(forKey: "pngCompressionTool"),
           let tool = PNGCompressionTool(rawValue: toolRaw) {
            self.pngCompressionTool = tool
        }
        if UserDefaults.standard.object(forKey: "pngQuantMinQuality") != nil {
            self.pngQuantMinQuality = UserDefaults.standard.double(forKey: "pngQuantMinQuality")
        }
        if UserDefaults.standard.object(forKey: "pngQuantMaxQuality") != nil {
            self.pngQuantMaxQuality = UserDefaults.standard.double(forKey: "pngQuantMaxQuality")
        }
        if UserDefaults.standard.object(forKey: "pngQuantSpeed") != nil {
            self.pngQuantSpeed = UserDefaults.standard.integer(forKey: "pngQuantSpeed")
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
        if UserDefaults.standard.object(forKey: "useAutoBitrate") != nil {
            self.useAutoBitrate = UserDefaults.standard.bool(forKey: "useAutoBitrate")
        }
        if UserDefaults.standard.object(forKey: "customVideoBitrate") != nil {
            self.customVideoBitrate = UserDefaults.standard.integer(forKey: "customVideoBitrate")
        }
        
        // Load audio settings
        if let formatRaw = UserDefaults.standard.string(forKey: "audioFormat"),
           let format = AudioFormat(rawValue: formatRaw) {
            self.audioFormat = format
        }
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
    
    func getVideoBitrate(targetSize: CGSize?, originalSize: CGSize?) -> Int {
        // If auto bitrate is disabled, return custom value
        if !useAutoBitrate {
            return max(500, customVideoBitrate)
        }
        
        // Prefer target resolution, fall back to original size, then default to 1080p
        let fallbackSize = CGSize(width: 1920, height: 1080)
        let referenceSize = targetSize ?? originalSize ?? fallbackSize
        let pixelCount = Double(referenceSize.width * referenceSize.height)
        let hdThreshold = Double(1280 * 720)
        let fullHDThreshold = Double(1920 * 1080)
        let twoKThreshold = Double(2560 * 1440)
        
        // Lower bitrates for better compression while maintaining acceptable quality
        if pixelCount <= hdThreshold {
            return 1500  // 720p: 1.5 Mbps
        } else if pixelCount <= fullHDThreshold {
            return 3000  // 1080p: 3 Mbps
        } else if pixelCount <= twoKThreshold {
            return 5000  // 2K: 5 Mbps
        } else {
            return 8000  // 4K: 8 Mbps
        }
    }
    
    // Get target frame rate
    func getTargetFrameRate() -> Double {
        if let frameRate = frameRateMode.frameRateValue {
            return frameRate
        }
        return Double(customFrameRate)
    }
    
    // Generate FFmpeg command parameters
    func generateFFmpegCommand(
        inputPath: String,
        outputPath: String,
        videoSize: CGSize? = nil,
        originalFrameRate: Double? = nil,
        originalBitDepth: Int? = nil
    ) -> String {
        var command = ""
        
        // Always enable hardware acceleration before input when using VideoToolbox encoders
        command += "-hwaccel auto "
        
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
        
        // Compute target scaling size once for both bitrate estimation and optional scaling
        let resolvedTargetSize = targetVideoResolution.size(for: targetOrientationMode, originalSize: videoSize)
        
        // Video codec
        command += " -c:v \(effectiveCodec.ffmpegCodec)"

        // Debug: log inputs relevant to frame rate decisions
        print("🔍 [FFmpeg Debug] input=\(inputPath), output=\(outputPath), originalFrameRate=\(String(describing: originalFrameRate)), frameRateMode=\(frameRateMode.rawValue), customFrameRate=\(customFrameRate)")
        print("🔍 [FFmpeg Debug] effectiveCodec=\(effectiveCodec.ffmpegCodec), useAutoBitrate=\(useAutoBitrate)")
        
        // Quality control: VideoToolbox uses bitrate parameters while software encoders keep preset/CRF
        let codecIdentifier 
        = effectiveCodec.ffmpegCodec.lowercased()
        if codecIdentifier.contains("videotoolbox") {
            let targetKbps = getVideoBitrate(targetSize: resolvedTargetSize, originalSize: videoSize)
            let maxrate = Int(Double(targetKbps) * 1.2)
            let bufsize = Int(Double(targetKbps) * 2.0)
            command += " -b:v \(targetKbps)k -maxrate \(maxrate)k -bufsize \(bufsize)k"
        } else {
            command += " -preset \(videoQualityPreset.ffmpegPreset)"
            let crfValue = getCRFValue()
            command += " -crf \(crfValue)"
        }
        
        // Collect video filters
        var vfParts: [String] = []
        var scaleInfo: (width: Int, height: Int)? = nil
        
        // Resolution scaling - only scale down if target is smaller than original
        if let originalSize = videoSize, let targetSize = resolvedTargetSize {
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
                
                vfParts.append("scale=\(evenWidth):\(evenHeight)")
                scaleInfo = (evenWidth, evenHeight)
                print("🎬 [FFmpeg] Scaling video from \(Int(originalWidth))×\(Int(originalHeight)) to \(evenWidth)×\(evenHeight)")
            } else {
                print("🎬 [FFmpeg] Keeping original resolution \(Int(originalWidth))×\(Int(originalHeight)) (target: \(Int(targetWidth))×\(Int(targetHeight)))")
            }
        }
        
        // Frame rate control - smart CFR decision
        let targetFPS = getTargetFrameRate()
        print("🔍 [FFmpeg Debug] Calculated targetFPS=\(targetFPS)")
        
        var shouldForceCFR = false
        var cfrReason = ""
        
        if let originalFPS = originalFrameRate {
            print("🔍 [FFmpeg Debug] originalFPS=\(originalFPS) (provided)")
            
            // Calculate difference percentage
            let fpsDiff = abs(targetFPS - originalFPS)
            let diffPercent = (fpsDiff / originalFPS) * 100.0
            
            print("🔍 [FFmpeg Debug] FPS difference: \(String(format: "%.2f", fpsDiff)) fps (\(String(format: "%.1f", diffPercent))%)")
            
            // Force CFR if difference is > 5%
            if diffPercent > 5.0 {
                shouldForceCFR = true
                cfrReason = "FPS差异>5% (\(String(format: "%.1f", diffPercent))%)"
                print("🎬 [FFmpeg] Will force CFR: target \(targetFPS) fps differs significantly from original \(originalFPS) fps")
            } else {
                print("🎬 [FFmpeg] Keeping original frame rate \(originalFPS) fps (difference \(String(format: "%.1f", diffPercent))% < 5%)")
            }
        } else {
            // No original frame rate info - be conservative, don't force CFR
            print("🎬 [FFmpeg] Original frame rate unknown, will not force CFR (保守策略)")
        }
        
        // Apply frame rate control
        if shouldForceCFR {
            // Use fps filter for reliable CFR output
            vfParts.insert("fps=\(targetFPS)", at: 0)
            print("✅ [FFmpeg] Forcing CFR with fps filter: \(targetFPS) fps (原因: \(cfrReason))")
        }
        
        // Build final -vf command if we have filters
        if !vfParts.isEmpty {
            command += " -vf \"\(vfParts.joined(separator: ","))\""
        }
        
        // Add fps_mode if forcing CFR (replaces deprecated -vsync)
        if shouldForceCFR {
            command += " -fps_mode cfr"
        }
        
        // Audio encoding
        command += " -c:a aac -b:a 128k"

        let useTenBitHEVC = effectiveCodec == .h265 && (originalBitDepth ?? 8) >= 10
        if useTenBitHEVC {
            command += " -pix_fmt p010le -profile:v main10"
            print("🎬 [FFmpeg] Preserving 10-bit HEVC output (profile main10)")
        } else {
            command += " -pix_fmt yuv420p"
        }

        if effectiveCodec == .h264 {
            command += " -tag:v avc1"  // Use avc1 tag for H.264 (AVC)
        } else if effectiveCodec == .h265 {
            let hevcTag = useTenBitHEVC ? "hev1" : "hvc1"
            command += " -tag:v \(hevcTag)"  // Adjust sample entry for HEVC compatibility
        }

        
        // Enable fast start for progressive streaming
        command += " -movflags +faststart"
        
        // Output file
        command += " \"\(outputPath)\""

        // Debug: print final command to help diagnose why output fps differs
        print("🔍 [FFmpeg Debug] Final command: \(command)")

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
    @Published var targetAudioFormat: AudioFormat = .mp3 {
        didSet { UserDefaults.standard.set(targetAudioFormat.rawValue, forKey: "targetAudioFormat") }
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
        if let audioFormatRaw = UserDefaults.standard.string(forKey: "targetAudioFormat"),
           let audioFormat = AudioFormat(rawValue: audioFormatRaw),
           audioFormat != .original {  // 格式转换不支持"原始"选项
            self.targetAudioFormat = audioFormat
        }
        if UserDefaults.standard.object(forKey: "useHEVC") != nil {
            self.useHEVC = UserDefaults.standard.bool(forKey: "useHEVC")
        }
        if UserDefaults.standard.object(forKey: "preserveExif") != nil {
            self.preserveExif = UserDefaults.standard.bool(forKey: "preserveExif")
        }
    }
}
