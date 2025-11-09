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

final class MediaCompressor {
    static func compressImage(
        _ data: Data,
        settings: CompressionSettings,
        preferredFormat: ImageFormat? = nil,
        progressHandler: ((Float) -> Void)? = nil
    ) async throws -> Data {
        guard var image = UIImage(data: data) else { throw MediaCompressionError.imageDecodeFailed }
        
        progressHandler?(0.1)
        
        // 修正图片方向，防止压缩后旋转
        image = image.fixOrientation()
        print("原始图片尺寸 - width:\(image.size.width), height:\(image.size.height)")

        progressHandler?(0.15)
        
        // 检测原始图片格式，保持原有格式
        // 如果提供了 preferredFormat，优先使用它；否则从数据检测
        let format: ImageFormat
        if let preferredFormat = preferredFormat {
            format = preferredFormat
            print("📋 [格式检测] 使用预设格式: \(preferredFormat == .heic ? "HEIC" : "JPEG")")
        } else {
            format = detectImageFormat(data: data)
        }
        
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
            // WebP 压缩 - 使用 SDWebImageWebPCoder
            print("🔄 [WebP] 开始 WebP 压缩 - 质量: \(quality)")
            
            let webpCoder = SDImageWebPCoder.shared
            let normalizedQuality = max(0.01, min(1.0, quality))
            
            // 使用 SDWebImageWebPCoder 编码
            if let webpData = webpCoder.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: normalizedQuality]) {
                progressHandler?(1.0)
                print("✅ [WebP] 压缩成功 - 质量: \(normalizedQuality), 大小: \(webpData.count) bytes")
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
            progressHandler: progressHandler,
            completion: completion
        )
        
        return nil  // FFmpeg 不使用 AVAssetExportSession
    }
    
    // 保留旧的 AVAssetExportSession 方法作为备用
    static func compressVideoLegacy(
        at sourceURL: URL,
        settings: CompressionSettings,
        outputFileType: AVFileType = .mp4,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> AVAssetExportSession? {
        let asset = AVURLAsset(url: sourceURL)
        
        // 获取视频轨道信息
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(MediaCompressionError.videoExportFailed))
            return nil
        }
        
        let videoSize = videoTrack.naturalSize
        let bitrate = settings.calculateBitrate(for: videoSize)
        
        print("视频压缩 - 原始分辨率: \(videoSize), 目标比特率: \(bitrate) bps (\(Double(bitrate) / 1_000_000) Mbps)")
        
        // 创建输出 URL
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)
        
        // 使用 Passthrough 预设，然后通过 VideoComposition 应用压缩设置
        // 注意：AVAssetExportSession 的预设选项有限，我们需要使用自定义的 videoComposition
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            // 如果 Passthrough 不可用，尝试使用 MediumQuality
            guard let fallbackSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetMediumQuality
            ) else {
                completion(.failure(MediaCompressionError.videoExportFailed))
                return nil
            }
            return configureExportSession(
                fallbackSession,
                asset: asset,
                videoTrack: videoTrack,
                videoSize: videoSize,
                bitrate: bitrate,
                outputURL: outputURL,
                outputFileType: outputFileType,
                progressHandler: progressHandler,
                completion: completion
            )
        }
        
        return configureExportSession(
            exportSession,
            asset: asset,
            videoTrack: videoTrack,
            videoSize: videoSize,
            bitrate: bitrate,
            outputURL: outputURL,
            outputFileType: outputFileType,
            progressHandler: progressHandler,
            completion: completion
        )
    }
    
    private static func configureExportSession(
        _ exportSession: AVAssetExportSession,
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        videoSize: CGSize,
        bitrate: Int,
        outputURL: URL,
        outputFileType: AVFileType,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) -> AVAssetExportSession {
        exportSession.outputURL = outputURL
        exportSession.outputFileType = outputFileType
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 创建视频合成来保持原始分辨率和变换，并应用压缩设置
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        
        // 保持原始帧率
        let frameRate = videoTrack.nominalFrameRate
        if frameRate > 0 {
            videoComposition.frameDuration = CMTime(value: 1, timescale: Int32(frameRate))
        } else {
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        }
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        exportSession.videoComposition = videoComposition
        
        // 使用 AVAssetWriter 来精确控制比特率
        // 由于 AVAssetExportSession 无法直接设置比特率，我们需要使用 AVAssetWriter
        Task {
            do {
                let outputURL = try await compressVideoWithWriter(
                    asset: asset,
                    videoTrack: videoTrack,
                    videoSize: videoSize,
                    bitrate: bitrate,
                    outputURL: outputURL,
                    progressHandler: progressHandler
                )
                completion(.success(outputURL))
            } catch {
                // 如果 AVAssetWriter 失败，回退到使用 exportSession（虽然可能不会压缩）
                print("使用 AVAssetWriter 压缩失败，回退到 exportSession: \(error.localizedDescription)")
                
                // 设置进度监听
                let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    let progress = exportSession.progress
                    progressHandler(progress)
                    
                    if exportSession.status != .exporting {
                        timer.invalidate()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                
                // 开始导出
                exportSession.exportAsynchronously {
                    DispatchQueue.main.async {
                        timer.invalidate()
                        progressHandler(1.0)
                        
                        switch exportSession.status {
                        case .completed:
                            completion(.success(outputURL))
                        case .cancelled:
                            completion(.failure(MediaCompressionError.exportCancelled))
                        default:
                            let error = exportSession.error ?? MediaCompressionError.videoExportFailed
                            print("视频压缩失败: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
        
        return exportSession
    }
    
    private static func compressVideoWithWriter(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        videoSize: CGSize,
        bitrate: Int,
        outputURL: URL,
        progressHandler: @escaping (Float) -> Void
    ) async throws -> URL {
        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)
        
        // 根据文件扩展名确定输出类型
        let fileType: AVFileType
        switch outputURL.pathExtension.lowercased() {
        case "mov":
            fileType = .mov
        case "m4v":
            fileType = .m4v
        default:
            fileType = .mp4
        }
        
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: fileType) else {
            throw MediaCompressionError.videoExportFailed
        }
        
        // 配置视频输出设置
        var videoCodec: AVVideoCodecType
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoMaxKeyFrameIntervalKey: 30
        ]
        
        // 根据输出格式选择合适的编码器
        switch fileType {
        case .mov:
            // MOV 格式支持 H.264 和 ProRes
            if bitrate > 50_000_000 { // 高比特率使用 ProRes
                videoCodec = .proRes422
            } else {
                videoCodec = .h264
                compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
                compressionProperties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
            }
        case .m4v:
            // M4V 格式通常使用 H.264
            videoCodec = .h264
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
            compressionProperties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
        default:
            // MP4 默认使用 H.264
            videoCodec = .h264
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
            compressionProperties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC
        }
        
        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: videoCodec,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        videoInput.transform = videoTrack.preferredTransform
        videoInput.expectsMediaDataInRealTime = false
        
        guard assetWriter.canAdd(videoInput) else {
            throw MediaCompressionError.videoExportFailed
        }
        assetWriter.add(videoInput)
        
        // 处理音频轨道（如果有）
        var audioInput: AVAssetWriterInput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            // 根据输出格式选择音频编码器
            let (audioFormat, audioBitrate) = fileType == .mov ? 
                (kAudioFormatLinearPCM, 1411200) : // MOV 使用无损音频
                (kAudioFormatMPEG4AAC, 256000)    // MP4/M4V 使用 AAC
                
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: audioFormat,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: audioBitrate
            ]
            
            let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            audioWriterInput.expectsMediaDataInRealTime = false
            
            if assetWriter.canAdd(audioWriterInput) {
                assetWriter.add(audioWriterInput)
                audioInput = audioWriterInput
            }
        }
        
        guard assetWriter.startWriting() else {
            throw assetWriter.error ?? MediaCompressionError.videoExportFailed
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        // 创建读取器
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            throw MediaCompressionError.videoExportFailed
        }
        
        // 配置视频读取器
        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        videoReaderOutput.alwaysCopiesSampleData = false
        
        if assetReader.canAdd(videoReaderOutput) {
            assetReader.add(videoReaderOutput)
        }
        
        // 配置音频读取器
        var audioReaderOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let audioInput = audioInput {
            let audioOutput = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM
                ]
            )
            audioOutput.alwaysCopiesSampleData = false
            
            if assetReader.canAdd(audioOutput) {
                assetReader.add(audioOutput)
                audioReaderOutput = audioOutput
            }
        }
        
        guard assetReader.startReading() else {
            throw assetReader.error ?? MediaCompressionError.videoExportFailed
        }
        
        let duration = asset.duration.seconds
        let videoQueue = DispatchQueue(label: "videoQueue")
        let audioQueue = DispatchQueue(label: "audioQueue")
        
        // 使用 DispatchGroup 来协调视频和音频的处理
        let group = DispatchGroup()
        
        // 处理视频
        group.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoInput.isReadyForMoreMediaData {
                guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
                
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let progress = Float(presentationTime.seconds / duration)
                DispatchQueue.main.async {
                    progressHandler(min(progress, 0.95)) // 保留 5% 给音频和完成
                }
                
                if !videoInput.append(sampleBuffer) {
                    print("视频写入失败: \(assetWriter.error?.localizedDescription ?? "未知错误")")
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
            }
        }
        
        // 处理音频
        if let audioInput = audioInput, let audioReaderOutput = audioReaderOutput {
            group.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() else {
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                    
                    if !audioInput.append(sampleBuffer) {
                        print("音频写入失败: \(assetWriter.error?.localizedDescription ?? "未知错误")")
                        audioInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }
        }
        
        // 等待所有处理完成
        group.notify(queue: .main) {
            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    progressHandler(1.0)
                }
            }
        }
        
        // 等待写入完成
        await withCheckedContinuation { continuation in
            // 使用定时器检查写入状态
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if assetWriter.status == .completed || assetWriter.status == .failed || assetWriter.status == .cancelled {
                    timer.invalidate()
                    continuation.resume()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
        }
        
        if assetWriter.status == .completed {
            return outputURL
        } else {
            throw assetWriter.error ?? MediaCompressionError.videoExportFailed
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
