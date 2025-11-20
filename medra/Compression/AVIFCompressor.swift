//
//  AVIFCompressor.swift
//  hummingbird
//
//  AVIF Image Compressor using FFmpeg with libaom-av1
//

import Foundation
import UniformTypeIdentifiers
import ImageIO
import UIKit
import ffmpegkit

struct AVIFCompressionResult {
    let data: Data
    let originalSize: Int
    let compressedSize: Int
}

struct AVIFCompressor {
    
    /// Compress image to AVIF format using FFmpeg
    /// - Parameters:
    ///   - image: Source UIImage
    ///   - quality: Quality value 0.1-1.0 (mapped to CRF 63-10)
    ///   - speedPreset: Encoding speed preset (maps to cpu-used 0-8)
    ///   - progressHandler: Optional progress callback
    /// - Returns: Compressed AVIF data or nil if failed
    static func compress(
        image: UIImage,
        quality: Double = 0.85,
        speedPreset: AVIFSpeedPreset = .balanced,
        backend: AVIFEncoderBackend = .systemImageIO,
        progressHandler: ((Float) -> Void)? = nil
    ) async -> AVIFCompressionResult? {
        
        print("🧪 [AVIF] Requested backend: \(backend.displayName)")
        
        progressHandler?(0.05)
        
        // 如果外层提供了 progressHandler，这里启一个后台“心跳”，在真正编码过程中定期向前推进一点进度，
        // 避免 UI 在长时间编码期间完全不动，看起来像卡死。
        let progressTicker: Task<Void, Never>?
        if let progressHandler {
            progressTicker = Task.detached(priority: .background) {
                var current: Float = 0.05
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
                    if Task.isCancelled { break }
                    current = min(current + 0.05, 0.95)
                    progressHandler(current)
                }
            }
        } else {
            progressTicker = nil
        }
        
        // Get PNG representation of source image (preserve alpha) for size tracking / ffmpeg fallback
        guard let sourceData = image.pngData() else {
            print("❌ [AVIF] Failed to get PNG data from source image")
            progressTicker?.cancel()
            return nil
        }
        
        let originalSize = sourceData.count
        
        // Select backend in priority order
        switch backend {
        case .systemImageIO:
            print("🧪 [AVIF] Trying backend: System ImageIO")
            if let imageIOResult = encodeUsingImageIO(image: image, quality: quality, originalSize: originalSize) {
                print("🧪 [AVIF] Compression completed with backend: System ImageIO")
                progressTicker?.cancel()
                progressHandler?(1.0)
                return imageIOResult
            }
            print("🧪 [AVIF] System ImageIO failed, falling back to libavif")
            if let libavifResult = encodeUsingLibavif(image: image, quality: quality, originalSize: originalSize) {
                print("🧪 [AVIF] Compression completed with backend: libavif (Native)")
                progressTicker?.cancel()
                progressHandler?(1.0)
                return libavifResult
            }
        case .libavif:
            if let libavifResult = encodeUsingLibavif(image: image, quality: quality, originalSize: originalSize) {
                print("🧪 [AVIF] Compression completed with backend: libavif (Native)")
                progressTicker?.cancel()
                progressHandler?(1.0)
                return libavifResult
            }
            print("🧪 [AVIF] libavif failed, falling back to System ImageIO")
            if let imageIOResult = encodeUsingImageIO(image: image, quality: quality, originalSize: originalSize) {
                print("🧪 [AVIF] Compression completed with backend: System ImageIO")
                progressTicker?.cancel()
                progressHandler?(1.0)
                return imageIOResult
            }
        }
        
        progressTicker?.cancel()
        print("⚠️ [AVIF] All native AVIF backends (System ImageIO, libavif) failed for still image, returning original image data")
        return AVIFCompressionResult(
            data: sourceData,
            originalSize: originalSize,
            compressedSize: originalSize
        )
    }

    // MARK: - libavif encoder

    private static func encodeUsingLibavif(image: UIImage, quality: Double, originalSize: Int) -> AVIFCompressionResult? {
        let normalizedQuality = max(0.1, min(1.0, quality))
        
        guard let cgImage = createCGImage(from: image.fixOrientation()) else {
            print("⚠️ [AVIF] libavif encoder: unable to create CGImage")
            return nil
        }
        
        guard let (rgbaData, rowBytes) = makeRGBABuffer(from: cgImage) else {
            print("⚠️ [AVIF] libavif encoder: unable to extract RGBA buffer")
            return nil
        }
        
        guard let avifImage = avifImageCreate(UInt32(cgImage.width),
                                              UInt32(cgImage.height),
                                              8,
                                              AVIF_PIXEL_FORMAT_YUV444) else {
            print("❌ [AVIF] libavif encoder: failed to create avifImage")
            return nil
        }
        defer { avifImageDestroy(avifImage) }
        
        avifImage.pointee.colorPrimaries = avifColorPrimaries(UInt16(AVIF_COLOR_PRIMARIES_BT709))
        avifImage.pointee.transferCharacteristics = avifTransferCharacteristics(UInt16(AVIF_TRANSFER_CHARACTERISTICS_SRGB))
        avifImage.pointee.matrixCoefficients = avifMatrixCoefficients(UInt16(AVIF_MATRIX_COEFFICIENTS_BT709))
        avifImage.pointee.yuvRange = AVIF_RANGE_FULL
        
        var rgbImage = avifRGBImage()
        avifRGBImageSetDefaults(&rgbImage, avifImage)
        rgbImage.format = AVIF_RGB_FORMAT_RGBA
        rgbImage.depth = 8
        rgbImage.rowBytes = UInt32(rowBytes)
        rgbImage.alphaPremultiplied = AVIF_TRUE
        
        let convertedToYUV: Bool = rgbaData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            rgbImage.pixels = UnsafeMutablePointer<UInt8>(mutating: baseAddress)
            let result = avifImageRGBToYUV(avifImage, &rgbImage)
            return result == AVIF_RESULT_OK
        }
        
        guard convertedToYUV else {
            print("❌ [AVIF] libavif encoder: RGB to YUV conversion failed")
            return nil
        }
        
        guard let encoder = avifEncoderCreate() else {
            print("❌ [AVIF] libavif encoder: failed to create encoder")
            return nil
        }
        defer { avifEncoderDestroy(encoder) }
        
        let quantizer = quantizerValue(for: normalizedQuality)
        let quantizerValue = Int32(quantizer)
        encoder.pointee.minQuantizer = quantizerValue
        encoder.pointee.maxQuantizer = quantizerValue
        encoder.pointee.minQuantizerAlpha = quantizerValue
        encoder.pointee.maxQuantizerAlpha = quantizerValue
        encoder.pointee.speed = Int32(AVIF_SPEED_DEFAULT)
        encoder.pointee.maxThreads = Int32(max(1, ProcessInfo.processInfo.processorCount))
        encoder.pointee.autoTiling = AVIF_TRUE
        
        var output = avifRWData(data: nil, size: 0)
        defer { avifRWDataFree(&output) }
        
        let writeResult = avifEncoderWrite(encoder, avifImage, &output)
        guard writeResult == AVIF_RESULT_OK, let encodedPtr = output.data else {
            let message = avifResultToString(writeResult).flatMap { String(cString: $0) } ?? "unknown error"
            print("❌ [AVIF] libavif encoder: encoding failed (\(message))")
            return nil
        }
        
        let compressedData = Data(bytes: encodedPtr, count: output.size)
        print("✅ [AVIF] libavif encoder successful - output size \(compressedData.count) bytes")
        print("🧪 [AVIF] Compression completed with backend: libavif (Native)")
        
        return AVIFCompressionResult(
            data: compressedData,
            originalSize: originalSize,
            compressedSize: compressedData.count
        )
    }
    
    /// Re-encode animated AVIF data while preserving animation using libavif.
    /// - Note: Uses libavif's decoder/encoder directly and keeps all frames and timing metadata.
    static func compressAnimated(
        avifData: Data,
        quality: Double = 0.85,
        speedPreset: AVIFSpeedPreset = .balanced,
        backend: AVIFEncoderBackend = .systemImageIO,
        progressHandler: ((Float) -> Void)? = nil
    ) async -> AVIFCompressionResult? {
        progressHandler?(0.05)
        let originalSize = avifData.count
        
        // 和静态 AVIF 一样，加一个后台“心跳”推进进度，避免长时间编码阶段 UI 完全不动
        let progressTicker: Task<Void, Never>?
        if let progressHandler {
            progressTicker = Task.detached(priority: .background) {
                var current: Float = 0.05
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
                    if Task.isCancelled { break }
                    current = min(current + 0.05, 0.95)
                    progressHandler(current)
                }
            }
        } else {
            progressTicker = nil
        }
        
        // libavif 直接处理动画序列：解码全部帧，再按质量/速度重新编码为动画 AVIF
        return avifData.withUnsafeBytes { rawBuffer -> AVIFCompressionResult? in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("❌ [AVIF] compressAnimated: unable to get raw pointer from Data")
                return nil
            }
            
            guard let decoder = avifDecoderCreate() else {
                print("❌ [AVIF] Failed to create avifDecoder for animated AVIF")
                return nil
            }
            defer { avifDecoderDestroy(decoder) }
            
            // 基本解码参数（使用 libavif 默认的大小/帧数限制，仅设置线程数）
            decoder.pointee.maxThreads = Int32(max(1, ProcessInfo.processInfo.processorCount))
            
            // 读入内存数据
            let setIOResult = avifDecoderSetIOMemory(decoder, baseAddress, avifData.count)
            guard setIOResult == AVIF_RESULT_OK else {
                let message = avifResultToString(setIOResult).flatMap { String(cString: $0) } ?? "unknown error"
                print("❌ [AVIF] avifDecoderSetIOMemory failed: \(message)")
                return nil
            }
            
            let parseResult = avifDecoderParse(decoder)
            guard parseResult == AVIF_RESULT_OK else {
                let message = avifResultToString(parseResult).flatMap { String(cString: $0) } ?? "unknown error"
                print("❌ [AVIF] avifDecoderParse failed: \(message)")
                return nil
            }
            
            let frameCount = max(1, decoder.pointee.imageCount)
            if frameCount <= 1 {
                print("⚠️ [AVIF] compressAnimated called on non-animated AVIF (frameCount=\(frameCount)), skipping")
                return nil
            }
            
            print("🎬 [AVIF] Detected animated AVIF with \(frameCount) frames, re-encoding with libavif (preserve animation)")
            
            // 创建 encoder（始终使用 libavif，忽略 backend，因为 System ImageIO 不支持动画）
            guard let encoder = avifEncoderCreate() else {
                print("❌ [AVIF] Failed to create avifEncoder for animated AVIF")
                return nil
            }
            defer { avifEncoderDestroy(encoder) }
            
            let quantizer = quantizerValue(for: quality)
            let quantizerValue = Int32(quantizer)
            encoder.pointee.minQuantizer = quantizerValue
            encoder.pointee.maxQuantizer = quantizerValue
            encoder.pointee.minQuantizerAlpha = quantizerValue
            encoder.pointee.maxQuantizerAlpha = quantizerValue
            encoder.pointee.speed = Int32(speedPreset.cpuUsedValue)
            encoder.pointee.maxThreads = Int32(max(1, ProcessInfo.processInfo.processorCount))
            encoder.pointee.autoTiling = AVIF_TRUE
            
            // 继承原始 timescale
            let timescale = decoder.pointee.timescale != 0 ? decoder.pointee.timescale : 30
            encoder.pointee.timescale = timescale
            
            var frameIndex: Int = 0
            while true {
                let nextResult = avifDecoderNextImage(decoder)
                if nextResult == AVIF_RESULT_OK {
                    frameIndex += 1
                    
                    // 使用原文件中的帧时长，如果缺失则设置为 1 个 timescale 单位
                    let timing = decoder.pointee.imageTiming
                    let duration = timing.durationInTimescales > 0 ? timing.durationInTimescales : 1
                    
                    let addResult = avifEncoderAddImage(
                        encoder,
                        decoder.pointee.image,
                        duration,
                        avifAddImageFlags(0) // AVIF_ADD_IMAGE_FLAG_NONE
                    )
                    if addResult != AVIF_RESULT_OK {
                        let message = avifResultToString(addResult).flatMap { String(cString: $0) } ?? "unknown error"
                        print("❌ [AVIF] avifEncoderAddImage failed at frame \(frameIndex): \(message)")
                        return nil
                    }
                    
                    let progress = 0.05 + (Double(frameIndex) / Double(frameCount)) * 0.8
                    progressHandler?(Float(progress))
                } else if nextResult == AVIF_RESULT_NO_IMAGES_REMAINING {
                    break
                } else {
                    let message = avifResultToString(nextResult).flatMap { String(cString: $0) } ?? "unknown error"
                    print("❌ [AVIF] avifDecoderNextImage failed: \(message)")
                    return nil
                }
            }
            
            var output = avifRWData(data: nil, size: 0)
            defer { avifRWDataFree(&output) }
            let finishResult = avifEncoderFinish(encoder, &output)
            guard finishResult == AVIF_RESULT_OK, let encodedPtr = output.data else {
                let message = avifResultToString(finishResult).flatMap { String(cString: $0) } ?? "unknown error"
                print("❌ [AVIF] avifEncoderFinish (animated) failed: \(message)")
                return nil
            }
            
            let compressedData = Data(bytes: encodedPtr, count: output.size)
            let compressedSize = compressedData.count
            print("✅ [AVIF] Animated compression success (libavif) - Original: \(originalSize) bytes -> \(compressedSize) bytes, frames: \(frameCount)")
            progressTicker?.cancel()
            progressHandler?(1.0)
            
            return AVIFCompressionResult(
                data: compressedData,
                originalSize: originalSize,
                compressedSize: compressedSize
            )
        }
    }
    
    /// Calculate CRF value from quality percentage
    /// Quality 100% → CRF 10 (best)
    /// Quality 85% → CRF 23 (recommended default)
    /// Quality 50% → CRF 35
    /// Quality 10% → CRF 55
    private static func calculateCRF(from quality: Double) -> Int {
        let normalized = max(0.1, min(1.0, quality))
        // Linear mapping: 1.0 → 10, 0.1 → 55
        let crf = 10 + (1.0 - normalized) * 45
        return Int(crf.rounded())
    }
    
    /// Decode AVIF file to UIImage using FFmpeg
    /// Useful for preview generation on iOS < 16
    static func decode(avifData: Data) async -> UIImage? {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent(UUID().uuidString + ".avif")
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
        
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Write AVIF to temp file
        do {
            try avifData.write(to: inputURL)
        } catch {
            print("❌ [AVIF Decode] Failed to write temp input file: \(error)")
            return nil
        }
        
        // Convert to PNG using FFmpeg
        let command = "-i \"\(inputURL.path)\" \"\(outputURL.path)\""
        
        let session = FFmpegKit.execute(command)
        
        guard let returnCode = session?.getReturnCode(), ReturnCode.isSuccess(returnCode) else {
            print("❌ [AVIF Decode] FFmpeg decoding failed")
            return nil
        }
        
        // Read PNG and create UIImage
        guard let pngData = try? Data(contentsOf: outputURL),
              let image = UIImage(data: pngData) else {
            print("❌ [AVIF Decode] Failed to create UIImage from decoded PNG")
            return nil
        }
        
        print("✅ [AVIF Decode] Successfully decoded AVIF to UIImage")
        return image
    }
    
    /// Detect total frame count for an AVIF image sequence using ffprobe
    static func detectFrameCount(avifData: Data) async -> Int {
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent(UUID().uuidString + "_frames.avif")
        defer { try? FileManager.default.removeItem(at: inputURL) }
        do {
            try avifData.write(to: inputURL)
        } catch {
            print("❌ [AVIF] Failed to write temp file for frame detection: \(error)")
            return 0
        }
        let command = "-v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 \"\(inputURL.path)\""
        let session = FFprobeKit.execute(command)
        guard let returnCode = session?.getReturnCode(), ReturnCode.isSuccess(returnCode) else {
            print("⚠️ [AVIF] Frame count detection failed: \(session?.getOutput() ?? "unknown error")")
            return 0
        }
        let output = session?.getOutput() ?? session?.getLogsAsString() ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let count = Int(trimmed) {
            return count
        }
        return 0
    }

    private static func encodeUsingImageIO(image: UIImage, quality: Double, originalSize: Int) -> AVIFCompressionResult? {
        guard let avifUTI = avifTypeIdentifier() else {
            return nil
        }
        guard let cgImage = createCGImage(from: image.fixOrientation()) else {
            print("⚠️ [AVIF] Unable to create CGImage for ImageIO encoder")
            return nil
        }
        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, avifUTI, 1, nil) else {
            return nil
        }
        let normalizedQuality = max(0.1, min(1.0, quality))
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: normalizedQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            print("⚠️ [AVIF] ImageIO encoder finalize failed")
            return nil
        }
        let compressedData = destinationData as Data
        print("✅ [AVIF] ImageIO encoder successful - output size \(compressedData.count) bytes")
        print("🧪 [AVIF] Compression completed with backend: System ImageIO")
        return AVIFCompressionResult(
            data: compressedData,
            originalSize: originalSize,
            compressedSize: compressedData.count
        )
    }
    
    private static func avifTypeIdentifier() -> CFString? {
        if #available(iOS 14.0, *) {
            let candidates: [UTType?] = [
                UTType(filenameExtension: "avif"),
                UTType(importedAs: "public.avif"),
                UTType(importedAs: "public.avci")
            ]
            if let resolved = candidates.compactMap({ $0 }).first {
                return resolved.identifier as CFString
            }
        }
        return "public.avif" as CFString
    }
    
    private static func createCGImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage {
            return cg
        }
        if let ciImage = image.ciImage {
            let context = CIContext(options: nil)
            return context.createCGImage(ciImage, from: ciImage.extent)
        }
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        let rendered = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rendered?.cgImage
    }
    private static func quantizerValue(for quality: Double) -> Int {
        let normalized = max(0.1, min(1.0, quality))
        let mapped = 10 + (1.0 - normalized) * 45.0
        return Int(mapped.rounded())
    }
    
    private static func makeRGBABuffer(from cgImage: CGImage) -> (Data, Int)? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        
        var data = Data(count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        let rendered = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
            context.draw(cgImage, in: rect)
            return true
        }
        
        guard rendered else {
            return nil
        }
        
        return (data, bytesPerRow)
    }
}
