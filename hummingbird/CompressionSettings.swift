//
//  CompressionSettings.swift
//  hummingbird
//
//  压缩设置模型
//

import Foundation
import SwiftUI
import Combine

// MARK: - 图片分辨率
enum ImageResolution: String, CaseIterable, Identifiable {
    case wallpaper4K = "4K 壁纸 (3840×2160)"
    case wallpaper2K = "2K 壁纸 (2560×1440)"
    case phoneWallpaperMax = "手机壁纸大 (1242×2688)"
    case phoneWallpaper = "手机壁纸 (1080×1920)"
    case wallpaperHD = "高清壁纸 (1920×1080)"
    case bannerLarge = "网站横幅大 (1920×600)"
    case socialVertical = "社交竖图 (1080×1350)"
    case bannerMedium = "网站横幅中 (1200×400)"
    case socialSquare = "社交方图 (1080×1080)"
    case videoCover720p = "视频封面 720p (1280×720)"
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

// MARK: - 比特率控制模式
enum BitrateControlMode: String, CaseIterable, Identifiable {
    case auto = "自动（根据质量）"
    case manual = "手动设置"
    
    var id: String { rawValue }
}

// MARK: - 压缩设置
class CompressionSettings: ObservableObject {
    // 图片设置
    @Published var imageQuality: Double = 0.75
    
    // 视频设置（保持原始分辨率，调整比特率）
    @Published var bitrateControlMode: BitrateControlMode = .auto
    @Published var customBitrate: Double = 5.0  // Mbps，用于手动模式
    
    // 计算实际使用的比特率（bps）
    func calculateBitrate(for videoSize: CGSize) -> Int {
        switch bitrateControlMode {
        case .auto:
            // 根据分辨率自动计算合理的比特率
            let pixelCount = videoSize.width * videoSize.height
            
            // 根据分辨率自动计算合理的比特率，确保文件变小但保持质量
            // 720p (1280x720 = 921,600) -> ~2 Mbps
            // 1080p (1920x1080 = 2,073,600) -> ~4 Mbps
            // 4K (3840x2160 = 8,294,400) -> ~8 Mbps
            let bitsPerPixel: Double
            if pixelCount <= 1_000_000 {  // <= 720p
                // 720p: 2 Mbps / 921,600 ≈ 2.17 bits/pixel，使用 2.0 确保压缩
                bitsPerPixel = 2.0
            } else if pixelCount <= 2_500_000 {  // <= 1080p
                // 1080p: 4 Mbps / 2,073,600 ≈ 1.93 bits/pixel，使用 1.9 确保压缩
                bitsPerPixel = 1.9
            } else if pixelCount <= 5_000_000 {  // <= 1440p 或竖屏 1080p+
                // 1440p 或竖屏高分辨率: 使用 1.5 bits/pixel
                bitsPerPixel = 1.5
            } else {  // > 1440p (4K等)
                // 4K: 8 Mbps / 8,294,400 ≈ 0.96 bits/pixel，使用 1.0 确保压缩
                bitsPerPixel = 1.0
            }
            
            return Int(pixelCount * bitsPerPixel)
        case .manual:
            // 使用用户设置的比特率（Mbps 转 bps）
            return Int(customBitrate * 1_000_000)
        }
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
