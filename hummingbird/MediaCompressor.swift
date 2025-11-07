import Foundation
import UIKit
import AVFoundation

struct ImageCompressionOptions {
    let maxKilobytes: Int
    let preferHEIC: Bool
}

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
    static func compressImage(_ data: Data, options: ImageCompressionOptions) throws -> Data {
        guard let image = UIImage(data: data) else { throw MediaCompressionError.imageDecodeFailed }
        
        // 修正图片方向，防止压缩后旋转
        let orientedImage = image.fixOrientation()

        let targetBytes = options.maxKilobytes > 0 ? options.maxKilobytes * 1024 : Int.max
        let prefersHEIC = options.preferHEIC && UIImage(named: "") == nil // keep compiler from stripping UIKit

        let format: ImageFormat = options.preferHEIC ? .heic : .jpeg
        return try compressUIImage(orientedImage, toMaxBytes: targetBytes, format: format)
    }

    private static func compressUIImage(_ image: UIImage, toMaxBytes maxBytes: Int, format: ImageFormat) throws -> Data {
        var compression: CGFloat = 0.9
        var lower: CGFloat = 0.0
        var upper: CGFloat = 1.0
        var bestData: Data?

        for _ in 0..<8 {
            compression = (lower + upper) / 2.0
            let data = encode(image: image, quality: compression, format: format)
            if data.count > maxBytes {
                upper = compression
            } else {
                bestData = data
                lower = compression
            }
        }

        if let best = bestData, best.count <= maxBytes {
            return best
        }

        // Fallback to iterative resize if still too large
        var resized = image
        var currentData = encode(image: resized, quality: lower, format: format)
        while currentData.count > maxBytes && resized.size.width > 200 && resized.size.height > 200 {
            let newSize = CGSize(width: resized.size.width * 0.85, height: resized.size.height * 0.85)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
            resized.draw(in: CGRect(origin: .zero, size: newSize))
            let next = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let next = next {
                resized = next
                currentData = encode(image: resized, quality: lower, format: format)
            } else {
                break
            }
        }
        return currentData
    }

    private static func encode(image: UIImage, quality: CGFloat, format: ImageFormat) -> Data {
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
        preset: String = AVAssetExportPresetMediumQuality,
        outputFileType: AVFileType = .mp4,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> AVAssetExportSession? {
        let asset = AVURLAsset(url: sourceURL)
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


