import Foundation
import UIKit
import AVFoundation
import Combine

enum MediaCompressionError: Error {
    case imageDecodeFailed
    case videoExportFailed
    case exportCancelled
}

enum ImageFormat {
    case jpeg
    case heic
}

final class MediaCompressor {
    static func compressImage(_ data: Data, settings: CompressionSettings) throws -> Data {
        guard var image = UIImage(data: data) else { throw MediaCompressionError.imageDecodeFailed }
        
        // 修正图片方向，防止压缩后旋转
        image = image.fixOrientation()
        
        // 根据设置调整尺寸
        let maxWidth = settings.actualImageMaxWidth
        let maxHeight = settings.actualImageMaxHeight
        if maxWidth > 0 || maxHeight > 0 {
            image = resizeImage(image, maxWidth: maxWidth, maxHeight: maxHeight)
        }

        // 检测原始图片格式，保持原有格式
        let format: ImageFormat = detectImageFormat(data: data)
        return encode(image: image, quality: CGFloat(settings.imageQuality), format: format)
    }
    
    private static func detectImageFormat(data: Data) -> ImageFormat {
        // 检查文件头来判断格式
        guard data.count > 12 else { return .jpeg }
        
        let bytes = [UInt8](data.prefix(12))
        
        // HEIC/HEIF 格式检测 (ftyp box)
        if bytes.count >= 12 {
            let ftypSignature = String(bytes: bytes[4..<8], encoding: .ascii)
            if ftypSignature == "ftyp" {
                let brand = String(bytes: bytes[8..<12], encoding: .ascii)
                if brand?.hasPrefix("heic") == true || brand?.hasPrefix("heix") == true ||
                   brand?.hasPrefix("hevc") == true || brand?.hasPrefix("mif1") == true {
                    return .heic
                }
            }
        }
        
        // JPEG 格式检测 (FF D8 FF)
        if bytes.count >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return .jpeg
        }
        
        // 默认使用 JPEG
        return .jpeg
    }
    
    private static func resizeImage(_ image: UIImage, maxWidth: Int, maxHeight: Int) -> UIImage {
        let size = image.size
        var targetSize = size
        
        // 计算缩放比例
        if maxWidth > 0 && size.width > CGFloat(maxWidth) {
            let ratio = CGFloat(maxWidth) / size.width
            targetSize = CGSize(width: CGFloat(maxWidth), height: size.height * ratio)
        }
        
        if maxHeight > 0 && targetSize.height > CGFloat(maxHeight) {
            let ratio = CGFloat(maxHeight) / targetSize.height
            targetSize = CGSize(width: targetSize.width * ratio, height: CGFloat(maxHeight))
        }
        
        // 如果尺寸没变，直接返回
        if targetSize == size {
            return image
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func encode(image: UIImage, quality: CGFloat, format: ImageFormat) -> Data {
        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: max(0.01, min(1.0, quality))) ?? Data()
        case .heic:
            if #available(iOS 11.0, *) {
                let mutableData = NSMutableData()
                guard let imageDestination = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil),
                      let cgImage = image.cgImage else {
                    return image.jpegData(compressionQuality: max(0.01, min(1.0, quality))) ?? Data()
                }
                let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
                CGImageDestinationAddImage(imageDestination, cgImage, options as CFDictionary)
                CGImageDestinationFinalize(imageDestination)
                return mutableData as Data
            } else {
                return image.jpegData(compressionQuality: max(0.01, min(1.0, quality))) ?? Data()
            }
        }
    }

    static func compressVideo(
        at sourceURL: URL,
        settings: CompressionSettings,
        outputFileType: AVFileType = .mp4,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> AVAssetExportSession? {
        let asset = AVURLAsset(url: sourceURL)
        
        // 根据质量选择预设
        let preset = qualityToPreset(settings.videoQuality)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            completion(.failure(MediaCompressionError.videoExportFailed))
            return nil
        }
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 设置视频分辨率
        if let targetSize = getTargetVideoSize(settings: settings, asset: asset) {
            exportSession.videoComposition = createVideoComposition(asset: asset, targetSize: targetSize)
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            progressHandler(exportSession.progress)
            if exportSession.status != .exporting { t.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .cancelled:
                    completion(.failure(MediaCompressionError.exportCancelled))
                default:
                    completion(.failure(exportSession.error ?? MediaCompressionError.videoExportFailed))
                }
            }
        }
        return exportSession
    }
    
    private static func qualityToPreset(_ quality: Double) -> String {
        switch quality {
        case 0..<0.4:
            return AVAssetExportPresetLowQuality
        case 0.4..<0.7:
            return AVAssetExportPresetMediumQuality
        default:
            return AVAssetExportPresetHighestQuality
        }
    }
    
    private static func getTargetVideoSize(settings: CompressionSettings, asset: AVAsset) -> CGSize? {
        switch settings.videoResolution {
        case .original:
            return nil
        case .custom:
            if let width = Int(settings.customWidth), let height = Int(settings.customHeight), width > 0, height > 0 {
                return CGSize(width: width, height: height)
            }
            return nil
        default:
            return settings.videoResolution.size
        }
    }
    
    private static func createVideoComposition(asset: AVAsset, targetSize: CGSize) -> AVMutableVideoComposition {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return AVMutableVideoComposition()
        }
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = targetSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        let videoSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        
        // 计算缩放比例
        let scaleX = targetSize.width / videoSize.width
        let scaleY = targetSize.height / videoSize.height
        let scale = min(scaleX, scaleY)
        
        var finalTransform = transform
        finalTransform = finalTransform.scaledBy(x: scale, y: scale)
        
        transformer.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [transformer]
        composition.instructions = [instruction]
        
        return composition
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
        
        // 计算正确的变换矩阵
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // 创建上下文并绘制图片
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let newCGImage = context.makeImage() else { return self }
        return UIImage(cgImage: newCGImage)
    }
}


