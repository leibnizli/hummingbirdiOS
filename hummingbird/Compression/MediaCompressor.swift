import Foundation
import UIKit
import AVFoundation
import Combine
import SDWebImageWebPCoder

enum MediaCompressionError: Error {
    case imageDecodeFailed
    case videoExportFailed
    case exportCancelled
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case heic = "HEIC"
    case png = "PNG"
    case webp = "WebP"
    
    var id: String { rawValue }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3"
    case aac = "AAC"
    case m4a = "M4A"
    case opus = "OPUS"
    case flac = "FLAC"
    case wav = "WAV"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .aac: return "aac"
        case .m4a: return "m4a"
        case .opus: return "opus"
        case .flac: return "flac"
        case .wav: return "wav"
        }
    }
    
    var description: String {
        switch self {
        case .mp3: return "Most compatible"
        case .aac: return "Good quality"
        case .m4a: return "Apple devices"
        case .opus: return "Best for low bitrate"
        case .flac: return "Lossless"
        case .wav: return "Uncompressed"
        }
    }
}

final class MediaCompressor {
    
    // Compress audio file
    static func compressAudio(
        at sourceURL: URL,
        settings: CompressionSettings,
        outputFormat: AudioFormat = .mp3,
        originalBitrate: Int?,
        originalSampleRate: Int?,
        originalChannels: Int?,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension(outputFormat.fileExtension)
        
        FFmpegAudioCompressor.compressAudio(
            inputURL: sourceURL,
            outputURL: outputURL,
            settings: settings,
            outputFormat: outputFormat,
            originalBitrate: originalBitrate,
            originalSampleRate: originalSampleRate,
            originalChannels: originalChannels,
            progressHandler: progressHandler,
            completion: completion
        )
    }
    
    static func compressImage(
        _ data: Data,
        settings: CompressionSettings,
        preferredFormat: ImageFormat? = nil,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> Data {
        progressHandler?(0.1)
        
        // 检测原始图片格式，保持原有格式
        // 如果提供了 preferredFormat，优先使用它；否则从数据检测
        let format: ImageFormat
        if let preferredFormat = preferredFormat {
            format = preferredFormat
            print("📋 [格式检测] 使用预设格式: \(preferredFormat.rawValue)")
        } else {
            format = detectImageFormat(data: data)
        }
        
        // 常规图片处理（包括 WebP）
        guard var image = UIImage(data: data) else { throw MediaCompressionError.imageDecodeFailed }
        
        // 修正图片方向，防止压缩后旋转
        image = image.fixOrientation()
        let originalSize = image.size
        print("📐 [Image] Original size: \(Int(originalSize.width))×\(Int(originalSize.height))")
        
        // Resolution scaling - only scale down if target is smaller than original
        if let targetSize = settings.targetImageResolution.size(for: settings.targetImageOrientationMode, originalSize: originalSize) {
            let originalWidth = originalSize.width
            let originalHeight = originalSize.height
            let targetWidth = targetSize.width
            let targetHeight = targetSize.height
            
            let originalOrientation = originalWidth >= originalHeight ? "Landscape" : "Portrait"
            let targetOrientation = targetWidth >= targetHeight ? "Landscape" : "Portrait"
            
            print("📐 [Image] Original: \(Int(originalWidth))×\(Int(originalHeight)) (\(originalOrientation))")
            print("📐 [Image] Target: \(Int(targetWidth))×\(Int(targetHeight)) (\(targetOrientation))")
            print("📐 [Image] Orientation Mode: \(settings.targetImageOrientationMode.rawValue)")
            
            // Only scale if original is larger than target
            if originalWidth > targetWidth || originalHeight > targetHeight {
                // Calculate aspect ratio preserving scale
                let scaleWidth = targetWidth / originalWidth
                let scaleHeight = targetHeight / originalHeight
                let scale = min(scaleWidth, scaleHeight)
                
                let newSize = CGSize(width: originalWidth * scale, height: originalHeight * scale)
                
                print("📐 [Image] Scaling from \(Int(originalWidth))×\(Int(originalHeight)) to \(Int(newSize.width))×\(Int(newSize.height))")
                
                // Resize image
                image = resizeImage(image, targetSize: newSize)
            } else {
                print("📐 [Image] Keeping original resolution (target: \(Int(targetWidth))×\(Int(targetHeight)))")
            }
        }

        progressHandler?(0.15)
        progressHandler?(0.2)
        
        // 根据格式选择对应的质量设置
        let quality: CGFloat
        switch format {
        case .heic:
            quality = CGFloat(settings.heicQuality)
        case .jpeg:
            quality = CGFloat(settings.jpegQuality)
        case .webp:
            quality = CGFloat(settings.webpQuality)
        case .png:
            quality = 0.0  // PNG 不使用质量参数
        }
        
        return await encode(image: image, quality: quality, format: format, progressHandler: progressHandler)
    }
    
    static func detectImageFormat(data: Data) -> ImageFormat {
        // 检查文件头来判断格式
        guard data.count > 12 else {
            print("📋 [格式检测] 数据太小，默认使用 JPEG")
            return .jpeg
        }
        
        let bytes = [UInt8](data.prefix(12))
        let hexString = bytes.prefix(12).map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📋 [格式检测] 文件头 (前12字节): \(hexString)")
        
        // PNG 格式检测 (89 50 4E 47 0D 0A 1A 0A)
        if bytes.count >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
           bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A {
            print("✅ [格式检测] 检测到 PNG 格式")
            return .png
        }
        
        // HEIC/HEIF 格式检测 (ftyp box)
        if bytes.count >= 12 {
            let ftypSignature = String(bytes: bytes[4..<8], encoding: .ascii)
            print("📋 [格式检测] ftyp 签名: \(ftypSignature ?? "nil")")
            if ftypSignature == "ftyp" {
                let brand = String(bytes: bytes[8..<12], encoding: .ascii)
                print("📋 [格式检测] brand: \(brand ?? "nil")")
                if brand?.hasPrefix("heic") == true || brand?.hasPrefix("heix") == true ||
                   brand?.hasPrefix("hevc") == true || brand?.hasPrefix("mif1") == true {
                    print("✅ [格式检测] 检测到 HEIC 格式")
                    return .heic
                }
            }
        }
        
        // JPEG 格式检测 (FF D8 FF)
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            print("✅ [格式检测] 检测到 JPEG 格式")
            return .jpeg
        }
        
        // WebP 格式检测 (RIFF....WEBP)
        if bytes.count >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
           bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            print("✅ [格式检测] 检测到 WebP 格式")
            return .webp
        }
        
        // 默认使用 JPEG
        print("⚠️ [格式检测] 未识别格式，默认使用 JPEG")
        return .jpeg
    }

    static func encode(image: UIImage, quality: CGFloat, format: ImageFormat, progressHandler: ((Float) -> Void)? = nil) async -> Data {
        switch format {
        case .webp:
            progressHandler?(0.3)
            // WebP 压缩 - 使用 SDWebImageWebPCoder（静态图片）
            print("🔄 [WebP] 开始静态 WebP 压缩 - 质量: \(quality)")
            
            let webpCoder = SDImageWebPCoder.shared
            let normalizedQuality = max(0.01, min(1.0, quality))
            
            // 静态 WebP 编码
            if let webpData = webpCoder.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: normalizedQuality]) {
                progressHandler?(1.0)
                print("✅ [WebP] 静态压缩成功 - 质量: \(normalizedQuality), 大小: \(webpData.count) bytes")
                return webpData
            } else {
                print("⚠️ [WebP] SDWebImageWebPCoder 编码失败，回退到 JPEG")
                // WebP 编码失败，回退到 JPEG
                if let jpegData = image.jpegData(compressionQuality: normalizedQuality) {
                    progressHandler?(1.0)
                    print("✅ [WebP->JPEG 回退] 压缩成功 - 大小: \(jpegData.count) bytes")
                    return jpegData
                }
                progressHandler?(1.0)
                return Data()
            }
            
        case .png:
            // PNG 使用自定义压缩器
            print("🔄 [PNG] 使用颜色量化压缩")
            progressHandler?(0.3)
            
            if let compressedData = await PNGCompressor.compress(image: image, progressHandler: { progress in
                // 将 PNG 压缩器的进度映射到 0.3-1.0 范围
                let mappedProgress = 0.3 + (progress * 0.7)
                progressHandler?(mappedProgress)
            }) {
                print("✅ [PNG] 压缩成功 - 大小: \(compressedData.count) bytes")
                return compressedData
            } else {
                print("⚠️ [PNG] 压缩失败，使用原始 PNG")
                progressHandler?(1.0)
                return image.pngData() ?? Data()
            }
            
        case .jpeg:
            progressHandler?(0.3)
            // 使用 MozJPEG 压缩
            let normalizedQuality = max(0.01, min(1.0, quality))
            if let mozjpegData = MozJPEGEncoder.encode(image, quality: normalizedQuality) {
                let originalSize = image.jpegData(compressionQuality: normalizedQuality)?.count ?? 0
                let compressedSize = mozjpegData.count
                let compressionRatio = originalSize > 0 ? Double(compressedSize) / Double(originalSize) : 0.0
                progressHandler?(1.0)
                print("✅ [MozJPEG] 压缩成功 - 质量: \(normalizedQuality), 原始大小: \(originalSize) bytes, 压缩后: \(compressedSize) bytes, 压缩比: \(String(format: "%.2f%%", compressionRatio * 100))")
                return mozjpegData
            }
            // 如果 MozJPEG 失败，回退到系统默认
            print("⚠️ [MozJPEG] 压缩失败，回退到系统默认 JPEG 压缩 - 质量: \(normalizedQuality)")
            if let systemData = image.jpegData(compressionQuality: normalizedQuality) {
                progressHandler?(1.0)
                print("✅ [系统默认] JPEG 压缩成功 - 大小: \(systemData.count) bytes")
                return systemData
            } else {
                progressHandler?(1.0)
                print("❌ [系统默认] JPEG 压缩失败")
                return Data()
            }
        case .heic:
            progressHandler?(0.3)
            if #available(iOS 11.0, *) {
                print("🔄 [HEIC] 开始 HEIC 压缩 - 质量: \(quality)")
                let mutableData = NSMutableData()
                
                guard let cgImage = image.cgImage else {
                    print("❌ [HEIC] 错误: cgImage 为 nil")
                    return Data()
                }
                
                guard let imageDestination = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil) else {
                    print("❌ [HEIC] 错误: 无法创建 CGImageDestination")
                    return Data()
                }
                
                let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
                CGImageDestinationAddImage(imageDestination, cgImage, options as CFDictionary)
                
                let success = CGImageDestinationFinalize(imageDestination)
                if success {
                    let heicData = mutableData as Data
                    progressHandler?(1.0)
                    print("✅ [HEIC] 压缩成功 - 大小: \(heicData.count) bytes")
                    return heicData
                } else {
                    progressHandler?(1.0)
                    print("❌ [HEIC] 错误: CGImageDestinationFinalize 失败")
                    return Data()
                }
            } else {
                progressHandler?(1.0)
                print("⚠️ [HEIC] iOS 版本低于 11.0，不支持 HEIC")
                return Data()
            }
        }
    }


    static func compressVideo(
        at sourceURL: URL,
        settings: CompressionSettings,
        outputFileType: AVFileType = .mp4,
        originalFrameRate: Double? = nil,
        originalResolution: CGSize? = nil,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> AVAssetExportSession? {
        // 使用 FFmpeg 进行视频压缩
        // 以前此处优先使用 sourceURL 的扩展名，导致传入的 outputFileType 参数无法生效。
        // 现在优先依据 outputFileType 选择输出容器扩展名（以便调用方可以指定 mp4/mov/m4v 等），
        // 如果需要更多容器支持，可通过扩展此处的映射或改为接受字符串参数。
        let outputExtension: String
        switch outputFileType {
        case .mov:
            outputExtension = "mov"
        case .m4v:
            outputExtension = "m4v"
        default:
            outputExtension = "mp4"
        }
            
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension(outputExtension)
        
        FFmpegVideoCompressor.compressVideo(
            inputURL: sourceURL,
            outputURL: outputURL,
            settings: settings,
            originalFrameRate: originalFrameRate,
            originalResolution: originalResolution,
            progressHandler: progressHandler,
            completion: completion
        )
        
        return nil  // FFmpeg 不使用 AVAssetExportSession
    }

    // Resize image to target size
    static func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - UIImage Extension for Orientation Fix
extension UIImage {
    func fixOrientation() -> UIImage {
        // 如果图片方向已经是正确的，直接返回
        if imageOrientation == .up {
            return self
        }
        
        guard let cgImage = cgImage else { return self }
        
        // 检查图片是否有透明通道
        let hasAlpha = cgImage.alphaInfo != .none && 
                       cgImage.alphaInfo != .noneSkipFirst && 
                       cgImage.alphaInfo != .noneSkipLast
        
        // 使用 UIGraphicsImageRenderer 重新绘制，自动处理方向
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // 使用 1.0 保持像素尺寸不变
        format.opaque = !hasAlpha  // 根据是否有透明通道设置 opaque
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            // 如果有透明通道，确保背景是透明的
            if hasAlpha {
                context.cgContext.clear(CGRect(origin: .zero, size: size))
            }
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
