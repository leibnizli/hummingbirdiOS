//
//  PNGCompressor.swift
//  hummingbird
//
//  PNG 压缩器 - 使用系统内置方法实现颜色量化压缩
//

import UIKit
import CoreImage
import ImageIO

class PNGCompressor {
    
    /// 压缩 PNG 图片
    /// - Parameters:
    ///   - image: 原始图片
    ///   - progressHandler: 进度回调 (0.0 - 1.0)
    /// - Returns: 压缩后的 PNG 数据
    static func compress(image: UIImage, progressHandler: ((Float) -> Void)? = nil) async -> Data? {
        progressHandler?(0.05)
        
        guard let cgImage = image.cgImage else {
            print("❌ [PNG压缩] 无法获取 CGImage")
            return image.pngData()
        }
        
        progressHandler?(0.1)
        
        // 检查是否有透明通道
        let hasAlpha = cgImage.alphaInfo != .none &&
                       cgImage.alphaInfo != .noneSkipFirst &&
                       cgImage.alphaInfo != .noneSkipLast
        
        let originalSize = image.pngData()?.count ?? 0
        print("🔄 [PNG压缩] 开始压缩 - 尺寸: \(cgImage.width)x\(cgImage.height), 透明通道: \(hasAlpha), 原始大小: \(originalSize) bytes")
        
        progressHandler?(0.2)
        
        // 使用 CIImage 进行颜色量化处理
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ])
        
        progressHandler?(0.3)
        
        // 应用颜色量化滤镜
        guard let quantizedImage = applyColorQuantization(ciImage: ciImage, hasAlpha: hasAlpha) else {
            print("⚠️ [PNG压缩] 颜色量化失败，使用原图")
            progressHandler?(1.0)
            return image.pngData()
        }
        
        progressHandler?(0.5)
        
        // 渲染为 CGImage
        guard let outputCGImage = context.createCGImage(quantizedImage, from: quantizedImage.extent) else {
            print("⚠️ [PNG压缩] 渲染失败，使用原图")
            progressHandler?(1.0)
            return image.pngData()
        }
        
        progressHandler?(0.7)
        
        // 使用 ImageIO 进行优化的 PNG 编码
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
            print("⚠️ [PNG压缩] 无法创建 ImageDestination")
            progressHandler?(1.0)
            return image.pngData()
        }
        
        progressHandler?(0.8)
        
        // 设置 PNG 压缩选项
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8,  // 有损压缩质量
            kCGImagePropertyPNGCompressionFilter: 5  // PNG 压缩过滤器（5 = Paeth）
        ]
        
        CGImageDestinationAddImage(destination, outputCGImage, options as CFDictionary)
        
        progressHandler?(0.9)
        
        guard CGImageDestinationFinalize(destination) else {
            print("⚠️ [PNG压缩] 编码失败")
            progressHandler?(1.0)
            return image.pngData()
        }
        
        let compressedData = mutableData as Data
        let compressionRatio = originalSize > 0 ? Double(compressedData.count) / Double(originalSize) : 1.0
        
        progressHandler?(1.0)
        
        print("✅ [PNG压缩] 压缩完成 - 压缩后: \(compressedData.count) bytes, 压缩比: \(String(format: "%.1f%%", compressionRatio * 100))")
        return compressedData
    }
    
    /// 应用颜色量化
    private static func applyColorQuantization(ciImage: CIImage, hasAlpha: Bool) -> CIImage? {
        // 使用 CIColorPosterize 滤镜进行颜色量化
        // 这个滤镜可以减少图片中的颜色数量，类似 pngquant 的效果
        guard let posterizeFilter = CIFilter(name: "CIColorPosterize") else {
            print("⚠️ [PNG压缩] 无法创建 CIColorPosterize 滤镜")
            return ciImage
        }
        
        posterizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        // levels 参数控制每个颜色通道的级别数
        // 值越小，颜色越少，压缩率越高，但质量会下降
        // 8 是一个较好的平衡点，可以保持较好的视觉质量同时减小文件大小
        posterizeFilter.setValue(8, forKey: "inputLevels")
        
        guard let outputImage = posterizeFilter.outputImage else {
            print("⚠️ [PNG压缩] 颜色量化输出失败")
            return ciImage
        }
        
        return outputImage
    }
}
