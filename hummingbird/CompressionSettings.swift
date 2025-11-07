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
    case original = "原始分辨率"
    case wallpaper4K = "4K 壁纸 (3840×2160)"
    case wallpaper2K = "2K 壁纸 (2560×1440)"
    case wallpaperHD = "高清壁纸 (1920×1080)"
    case phoneWallpaper = "手机壁纸 (1080×1920)"
    case phoneWallpaperMax = "手机壁纸大 (1242×2688)"
    case bannerLarge = "网站横幅大 (1920×600)"
    case bannerMedium = "网站横幅中 (1200×400)"
    case socialSquare = "社交方图 (1080×1080)"
    case socialVertical = "社交竖图 (1080×1350)"
    case videoCover720p = "视频封面 720p (1280×720)"
    case videoCover1080p = "视频封面 1080p (1920×1080)"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var size: (width: Int, height: Int)? {
        switch self {
        case .original: return nil
        case .wallpaper4K: return (3840, 2160)
        case .wallpaper2K: return (2560, 1440)
        case .wallpaperHD: return (1920, 1080)
        case .phoneWallpaper: return (1080, 1920)
        case .phoneWallpaperMax: return (1242, 2688)
        case .bannerLarge: return (1920, 600)
        case .bannerMedium: return (1200, 400)
        case .socialSquare: return (1080, 1080)
        case .socialVertical: return (1080, 1350)
        case .videoCover720p: return (1280, 720)
        case .videoCover1080p: return (1920, 1080)
        case .custom: return nil
        }
    }
}

// MARK: - 压缩设置
class CompressionSettings: ObservableObject {
    // 图片设置
    @Published var imageResolution: ImageResolution = .original
    @Published var imageMaxWidth: Int = 0  // 0 表示不限制
    @Published var imageMaxHeight: Int = 0  // 0 表示不限制
    @Published var imageQuality: Double = 0.8
    
    // 视频设置
    @Published var videoQuality: Double = 0.6
    @Published var videoResolution: VideoResolution = .original
    @Published var customWidth: String = "1920"
    @Published var customHeight: String = "1080"
    
    // 计算属性：获取实际使用的图片最大宽度
    var actualImageMaxWidth: Int {
        if imageResolution == .custom {
            return imageMaxWidth
        } else if let size = imageResolution.size {
            return size.width
        }
        return 0
    }
    
    // 计算属性：获取实际使用的图片最大高度
    var actualImageMaxHeight: Int {
        if imageResolution == .custom {
            return imageMaxHeight
        } else if let size = imageResolution.size {
            return size.height
        }
        return 0
    }
}

// MARK: - 视频分辨率
enum VideoResolution: String, CaseIterable, Identifiable {
    case original = "原始分辨率"
    case uhd4k = "4K (3840×2160)"
    case fullHD = "1080p (1920×1080)"
    case hd = "720p (1280×720)"
    case sd = "480p (854×480)"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var size: CGSize? {
        switch self {
        case .original: return nil
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        case .fullHD: return CGSize(width: 1920, height: 1080)
        case .hd: return CGSize(width: 1280, height: 720)
        case .sd: return CGSize(width: 854, height: 480)
        case .custom: return nil
        }
    }
}
