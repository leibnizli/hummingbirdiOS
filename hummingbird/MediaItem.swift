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
    case pending      // 等待压缩
    case compressing  // 压缩中
    case completed    // 压缩完成
    case failed       // 压缩失败
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
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.2f MB", kb / 1024.0)
    }
}
