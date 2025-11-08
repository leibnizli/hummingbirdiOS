//
//  MediaItem.swift
//  hummingbird
//
//  媒体文件项模型
//

import Foundation
import SwiftUI
import PhotosUI
import Combine

enum CompressionStatus {
    case pending      // 等待处理
    case compressing  // 压缩中
    case processing   // 处理中（用于分辨率调整）
    case completed    // 完成
    case failed       // 失败
}

@MainActor
class MediaItem: Identifiable, ObservableObject {
    let id = UUID()
    let pickerItem: PhotosPickerItem
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
    
    // 分辨率信息
    @Published var originalResolution: CGSize?
    @Published var compressedResolution: CGSize?
    
    // 视频压缩使用的比特率（Mbps，仅视频有效）
    @Published var usedBitrate: Double?
    
    // 原始图片格式（从 PhotosPickerItem 检测）
    var originalImageFormat: ImageFormat?
    
    // 输出图片格式（压缩后的格式）
    var outputImageFormat: ImageFormat?
    
    // 输出视频格式（转换后的格式）
    var outputVideoFormat: String?
    
    // 临时文件URL（用于视频）
    var sourceVideoURL: URL?
    var compressedVideoURL: URL?
    
    init(pickerItem: PhotosPickerItem, isVideo: Bool) {
        self.pickerItem = pickerItem
        self.isVideo = isVideo
    }
    
    // 计算压缩率（减少的百分比）
    var compressionRatio: Double {
        guard originalSize > 0, compressedSize > 0 else { return 0 }
        return Double(originalSize - compressedSize) / Double(originalSize)
    }
    
    // 计算减少的大小
    var savedSize: Int {
        return originalSize - compressedSize
    }
    
    // 格式化字节大小
    func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.3f KB", kb) }
        return String(format: "%.3f MB", kb / 1024.0)
    }
    
    // 格式化分辨率
    func formatResolution(_ size: CGSize?) -> String {
        guard let size = size else { return "未知" }
        return "\(Int(size.width))×\(Int(size.height))"
    }
}
