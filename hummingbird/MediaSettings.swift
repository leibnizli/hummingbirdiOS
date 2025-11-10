//
//  MediaSettings.swift
//  hummingbird
//
//  媒体处理设置和模型
//

import Foundation
import SwiftUI
import Combine

// MARK: - 缩放模式
enum ResizeMode: String, CaseIterable, Identifiable {
    case cover = "填充 (Cover)"
    case fit = "适应 (Fit)"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .cover:
            return "等比例缩放填充目标尺寸，可能裁剪超出部分"
        case .fit:
            return "等比例缩放适应目标尺寸，保持完整内容，输出实际缩放后的尺寸"
        }
    }
}

// MARK: - 图片分辨率
enum ImageResolution: String, CaseIterable, Identifiable {
    case wallpaper4K = "3840×2160(4K)"
    case wallpaper2K = "2560×1440(2K)"
    case phoneWallpaperMax = "1242×2688"
    case phoneWallpaper = "1080×1920"
    case wallpaperHD = "1920×1080"
    case bannerLarge = "1920×600"
    case socialVertical = "1080×1350"
    case bannerMedium = "1200×400"
    case socialSquare = "1080×1080"
    case videoCover720p = "1280×720"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var size: (width: Int, height: Int)? {
        switch self {
        case .wallpaper4K: return (3840, 2160)
        case .wallpaper2K: return (2560, 1440)
        case .phoneWallpaperMax: return (1242, 2688)
        case .phoneWallpaper: return (1080, 1920)
        case .wallpaperHD: return (1920, 1080)
        case .bannerLarge: return (1920, 600)
        case .socialVertical: return (1080, 1350)
        case .bannerMedium: return (1200, 400)
        case .socialSquare: return (1080, 1080)
        case .videoCover720p: return (1280, 720)
        case .custom: return nil
        }
    }
}

// MARK: - 视频编码器
enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264 (兼容性好)"
    case h265 = "H.265/HEVC (压缩率高)"
    
    var id: String { rawValue }
    
    var ffmpegCodec: String {
        switch self {
        case .h264: return "h264_videotoolbox"  // 使用 iOS 硬件编码器
        case .h265: return "hevc_videotoolbox"  // 使用 iOS 硬件编码器
        }
    }
    
    var description: String {
        switch self {
        case .h264: return "使用硬件编码，兼容性最好"
        case .h265: return "使用硬件编码，文件更小"
        }
    }
}

// MARK: - 视频质量预设
enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case ultrafast = "极速 (质量较低)"
    case superfast = "超快 (质量一般)"
    case veryfast = "很快 (质量中等)"
    case faster = "较快 (质量较好)"
    case fast = "快速 (质量好)"
    case medium = "中等 (平衡)"
    case slow = "慢速 (质量很好)"
    case slower = "较慢 (质量极好)"
    case veryslow = "很慢 (质量最佳)"
    
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

// MARK: - CRF 质量模式
enum CRFQualityMode: String, CaseIterable, Identifiable {
    case veryHigh = "极高质量 (CRF 18)"
    case high = "高质量 (CRF 23)"
    case medium = "中等质量 (CRF 28)"
    case low = "低质量 (CRF 32)"
    case custom = "自定义"
    
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

// MARK: - 压缩设置
class CompressionSettings: ObservableObject {
    // 图片设置
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
    
    // 视频设置 - FFmpeg 参数
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
    
    init() {
        // 从 UserDefaults 加载保存的设置
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
    }
    
    // 获取 CRF 值
    func getCRFValue() -> Int {
        if let crfValue = crfQualityMode.crfValue {
            return crfValue
        }
        return customCRF
    }
    
    // 生成 FFmpeg 命令参数
    func generateFFmpegCommand(inputPath: String, outputPath: String, videoSize: CGSize? = nil) -> String {
        var command = ""
        
        // 硬件加速（必须在 -i 之前）
        if useHardwareAcceleration {
            command += "-hwaccel auto "
        }
        
        // 输入文件
        command += "-i \"\(inputPath)\""
        
        // 检测输出格式，M4V 容器只支持 H.264
        let outputExtension = (outputPath as NSString).pathExtension.lowercased()
        let effectiveCodec: VideoCodec
        
        if outputExtension == "m4v" {
            // M4V 容器不支持 HEVC，强制使用 H.264
            effectiveCodec = .h264
            if videoCodec == .h265 {
                print("⚠️ [FFmpeg] M4V 容器不支持 H.265，自动切换到 H.264")
            }
        } else {
            effectiveCodec = videoCodec
        }
        
        // 视频编码器
        command += " -c:v \(effectiveCodec.ffmpegCodec)"
        
        // 质量预设
        command += " -preset \(videoQualityPreset.ffmpegPreset)"
        
        // CRF 质量控制（恒定质量模式）
        let crfValue = getCRFValue()
        command += " -crf \(crfValue)"
        
        // 音频编码
        command += " -c:a aac -b:a 128k"
        
        // 像素格式 - 确保兼容性
        command += " -pix_fmt yuv420p"
        
        // 视频标签 - 对于 HEVC，添加兼容性标签
        if effectiveCodec == .h265 {
            command += " -tag:v hvc1"  // 使用 hvc1 标签以提高兼容性
        }
        
        // 保持元数据和优化
        command += " -movflags +faststart"
        
        // 输出文件
        command += " \"\(outputPath)\""
        
        return command
    }
}

// MARK: - 视频分辨率
enum VideoResolution: String, CaseIterable, Identifiable {
    case uhd4k = "4K (3840×2160)"
    case fullHD = "1080p (1920×1080)"
    case hd = "720p (1280×720)"
    case sd = "480p (854×480)"
    case custom = "自定义"
    
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

// MARK: - 分辨率设置
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
        // 从 UserDefaults 加载保存的设置
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

// MARK: - 格式转换设置
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
    
    init() {
        // 从 UserDefaults 加载保存的设置
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
    }
}
