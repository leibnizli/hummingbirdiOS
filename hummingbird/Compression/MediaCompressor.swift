import Foundation
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
    case avif = "AVIF"
    
    var id: String { rawValue }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case original = "Original"
    case mp3 = "MP3"
    case aac = "AAC"
    case m4a = "M4A"
    case opus = "OPUS"
    case flac = "FLAC"
    case wav = "WAV"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .original: return "" // Will use source format
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
        case .original: return "Keep original format"
        case .mp3: return "Most compatible"
        case .aac: return "Good quality"
        case .m4a: return "Apple devices"
        case .opus: return "Best for low bitrate"
        case .flac: return "Lossless"
        case .wav: return "Uncompressed"
        }
    }
    
    // Check if this format requires external encoder
    var requiresExternalEncoder: Bool {
        switch self {
        case .original:
            return false  // Will be determined by source format
        case .mp3, .opus:
            return true  // Requires libmp3lame, libopus
        case .aac, .m4a, .flac, .wav:
            return false  // Built-in encoders
        }
    }
    
    // Get encoder name for error messages
    var encoderName: String {
        switch self {
        case .original: return "original"
        case .mp3: return "libmp3lame"
        case .aac, .m4a: return "aac"
        case .opus: return "libopus"
        case .flac: return "flac"
        case .wav: return "pcm_s16le"
        }
    }
}

struct PNGCompressionReport {
    let tool: PNGCompressionTool
    let zopfliIterations: Int?
    let zopfliIterationsLarge: Int?
    let lossyTransparent: Bool?
    let lossy8bit: Bool?
    let paletteSize: Int?
    let quantizationQuality: Int?
    let appleColorMode: String?
    let appleOptimizations: [String]?

    init(tool: PNGCompressionTool,
         zopfliIterations: Int? = nil,
         zopfliIterationsLarge: Int? = nil,
         lossyTransparent: Bool? = nil,
         lossy8bit: Bool? = nil,
         paletteSize: Int? = nil,
         quantizationQuality: Int? = nil,
         appleColorMode: String? = nil,
         appleOptimizations: [String]? = nil) {
        self.tool = tool
        self.zopfliIterations = zopfliIterations
        self.zopfliIterationsLarge = zopfliIterationsLarge
        self.lossyTransparent = lossyTransparent
        self.lossy8bit = lossy8bit
        self.paletteSize = paletteSize
        self.quantizationQuality = quantizationQuality
        self.appleColorMode = appleColorMode
        self.appleOptimizations = appleOptimizations
    }
}

final class MediaCompressor {
    
    // Store last PNG compression parameters (actual applied values)
    static var lastPNGCompressionReport: PNGCompressionReport?
    
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
        
        // 特殊处理：检测动画 WebP
        if format == .webp {
            let originalSize = data.count
            print("🔍 [WebP] 开始检测 WebP 类型，原始大小: \(originalSize) bytes")
            
            // 检查文件头中的 VP8X 标志位
            var hasAnimationFlag = false
            if data.count >= 30 {
                let bytes = [UInt8](data.prefix(30))
                // VP8X chunk 在偏移 12 处，标志位在偏移 20 处
                if bytes.count >= 21 && bytes[12] == 0x56 && bytes[13] == 0x50 && bytes[14] == 0x38 && bytes[15] == 0x58 {
                    let flags = bytes[20]
                    hasAnimationFlag = (flags & 0x02) != 0  // 第 2 位表示动画
                    print("📊 [WebP] VP8X 标志位: 0x\(String(format: "%02X", flags)), 动画标志: \(hasAnimationFlag)")
                }
            }
            
            // 使用 SDAnimatedImage 检测帧数
            if let animatedImage = SDAnimatedImage(data: data) {
                let frameCount = animatedImage.animatedImageFrameCount
                print("📊 [WebP] SDAnimatedImage 检测帧数: \(frameCount)")
                
                if frameCount > 1 {
                    print("🎬 [WebP] 检测到动画 WebP，帧数: \(frameCount)")
                    
                    // 检查是否保留动画
                    if settings.preserveAnimatedWebP {
                        print("✅ [WebP] 设置：保留动画，开始压缩")
                        progressHandler?(0.2)
                        
                        let quality = CGFloat(settings.webpQuality)
                        return await encodeAnimatedWebP(
                            animatedImage: animatedImage,
                            quality: quality,
                            settings: settings,
                            originalSize: originalSize,
                            progressHandler: progressHandler
                        )
                    } else {
                        print("⚠️ [WebP] 设置：不保留动画，只保留第一帧")
                        // 继续常规处理，会自动只处理第一帧
                    }
                } else if hasAnimationFlag {
                    print("⚠️ [WebP] 文件头标记为动画，但 SDAnimatedImage 只检测到 \(frameCount) 帧")
                    print("⚠️ [WebP] 可能是 SDWebImage 版本问题，回退到静态处理")
                } else {
                    print("📋 [WebP] 静态 WebP（帧数: \(frameCount)），继续常规处理")
                }
            } else {
                print("⚠️ [WebP] SDAnimatedImage 初始化失败")
            }
        }
        
        // 常规图片处理（包括静态 WebP）
        guard var image = UIImage(data: data) else { throw MediaCompressionError.imageDecodeFailed }
        
        // 修正图片方向，防止压缩后旋转
        image = image.fixOrientation()
        let originalSize = image.size
        print("📐 [Image] Original size: \(Int(originalSize.width))×\(Int(originalSize.height))")
        
        // 标记是否调整了分辨率
        var resolutionChanged = false
        
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
                resolutionChanged = true
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
        case .avif:
            quality = CGFloat(settings.avifQuality)
        case .png:
            quality = 0.0  // PNG 不使用质量参数
        }

        // 动画 AVIF：根据设置进行特殊处理（以前使用 FFmpeg，多帧保留；现在改为静态重编码）
        let animatedAVIF = (format == .avif && isAnimatedAVIF(data: data))
        if animatedAVIF {
            if settings.preserveAnimatedAVIF {
                print("🎬 [AVIF] 检测到动画 AVIF，开始使用静态 AVIF 管线重新编码（将动画转为单帧静态图）")
                progressHandler?(0.25)
                if let result = await AVIFCompressor.compressAnimated(
                    avifData: data,
                    quality: Double(settings.avifQuality),
                    speedPreset: settings.avifSpeedPreset,
                    backend: settings.avifEncoderBackend,
                    progressHandler: { progress in
                        let mapped = 0.25 + (progress * 0.7)
                        progressHandler?(mapped)
                    }
                ) {
                    progressHandler?(1.0)
                    print("✅ [AVIF] 动画重新编码成功 - 原始: \(result.originalSize) bytes, 压缩后: \(result.compressedSize) bytes")
                    return result.data
                } else {
                    progressHandler?(1.0)
                    print("⚠️ [AVIF] 动画重新编码失败，保留原始数据")
                    return data
                }
            } else {
                print("⚠️ [AVIF] 动画已检测到，但设置为不保留动画，将转换为静态帧")
            }
        }
        
        // For PNG, pass original data to avoid re-encoding
        let originalPNGData = (format == .png) ? data : nil
        return await encode(image: image, quality: quality, format: format, settings: settings, originalPNGData: originalPNGData, resolutionChanged: resolutionChanged, progressHandler: progressHandler)
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
        
        // AVIF 格式检测 (ftyp box with avif/avis brand)
        if bytes.count >= 12 {
            let ftypSignature = String(bytes: bytes[4..<8], encoding: .ascii)
            if ftypSignature == "ftyp" {
                let brand = String(bytes: bytes[8..<12], encoding: .ascii)
                if brand?.hasPrefix("avif") == true || brand?.hasPrefix("avis") == true {
                    print("✅ [格式检测] 检测到 AVIF 格式")
                    return .avif
                }
            }
        }
        
        // 默认使用 JPEG
        print("⚠️ [格式检测] 未识别格式，默认使用 JPEG")
        return .jpeg
    }

    static func isAnimatedAVIF(data: Data) -> Bool {
        guard data.count >= 16 else { return false }
        let bytes = [UInt8](data.prefix(16))
        guard let ftypSignature = String(bytes: bytes[4..<8], encoding: .ascii), ftypSignature == "ftyp" else {
            return false
        }
        guard let brand = String(bytes: bytes[8..<12], encoding: .ascii) else {
            return false
        }
        if brand.hasPrefix("avis") {
            print("🎬 [AVIF] ftyp brand=\(brand)，识别为序列/动画 AVIF")
            return true
        }
        return false
    }

    // 编码动画 WebP
    static func encodeAnimatedWebP(
        animatedImage: SDAnimatedImage,
        quality: CGFloat,
        settings: CompressionSettings,
        originalSize: Int,
        progressHandler: ((Float) -> Void)?
    ) async -> Data {
        progressHandler?(0.3)
        print("🔄 [WebP] 开始动画 WebP 压缩 - 质量: \(quality)")
        print("📊 [WebP] 原始动画信息 - 帧数: \(animatedImage.animatedImageFrameCount), 循环次数: \(animatedImage.animatedImageLoopCount), 原始大小: \(originalSize) bytes")
        
        let webpCoder = SDImageWebPCoder.shared
        let normalizedQuality = max(0.01, min(1.0, quality))
        
        // 提取所有帧
        var frames: [SDImageFrame] = []
        for i in 0..<animatedImage.animatedImageFrameCount {
            if let frameImage = animatedImage.animatedImageFrame(at: i) {
                let duration = animatedImage.animatedImageDuration(at: i)
                let frame = SDImageFrame(image: frameImage, duration: duration)
                frames.append(frame)
                print("📸 [WebP] 提取帧 \(i+1)/\(animatedImage.animatedImageFrameCount) - 时长: \(duration)s")
            }
        }
        
        print("📊 [WebP] 共提取 \(frames.count) 帧")
        
        // 使用 encodedData(with:loopCount:format:options:) 方法编码动画
        // 注意：SDWebImageWebPCoder 默认使用有损压缩（VP8），不是无损（VP8L）
        let options: [SDImageCoderOption: Any] = [
            .encodeCompressionQuality: normalizedQuality,
            .encodeFirstFrameOnly: false  // 编码所有帧
        ]
        
        print("🔧 [WebP] 编码选项: quality=\(normalizedQuality), encodeFirstFrameOnly=false, frames=\(frames.count)")
        print("💡 [WebP] 提示：原始文件可能是无损 WebP，重新编码为有损格式")
        
        if let webpData = webpCoder.encodedData(with: frames, loopCount: animatedImage.animatedImageLoopCount, format: .webP, options: options) {
            // 验证压缩后的数据是否仍然是动画
            if let verifyImage = SDAnimatedImage(data: webpData) {
                let verifyFrameCount = verifyImage.animatedImageFrameCount
                let compressionRatio = Double(webpData.count) / Double(originalSize)
                
                print("✅ [WebP] 动画压缩成功")
                print("   - 质量: \(normalizedQuality)")
                print("   - 原始帧数: \(animatedImage.animatedImageFrameCount)")
                print("   - 压缩后帧数: \(verifyFrameCount)")
                print("   - 原始大小: \(originalSize) bytes")
                print("   - 压缩后大小: \(webpData.count) bytes")
                print("   - 压缩比: \(String(format: "%.1f%%", compressionRatio * 100))")
                
                if verifyFrameCount != animatedImage.animatedImageFrameCount {
                    print("⚠️ [WebP] 警告：帧数不匹配！可能丢失了动画")
                } else {
                    print("✅ [WebP] 帧数匹配，动画完整保留")
                }
                
                if webpData.count >= originalSize {
                    print("⚠️ [WebP] 压缩后反而变大，可能原始文件已经是高度优化的无损 WebP")
                    print("💡 [WebP] 建议：降低质量参数（当前 \(normalizedQuality)）或保留原始文件")
                }
            } else {
                print("⚠️ [WebP] 警告：无法验证压缩后的动画数据")
            }
            
            progressHandler?(1.0)
            return webpData
        } else {
            print("❌ [WebP] 动画编码失败，回退到第一帧")
            // 回退：只编码第一帧
            if let firstFrame = animatedImage.animatedImageFrame(at: 0),
               let webpData = webpCoder.encodedData(with: firstFrame, format: .webP, options: [.encodeCompressionQuality: normalizedQuality]) {
                progressHandler?(1.0)
                print("✅ [WebP] 回退到第一帧成功 - 大小: \(webpData.count) bytes")
                return webpData
            }
            progressHandler?(1.0)
            return Data()
        }
    }
    
    static func encode(image: UIImage, quality: CGFloat, format: ImageFormat, settings: CompressionSettings, originalPNGData: Data? = nil, resolutionChanged: Bool = false, progressHandler: ((Float) -> Void)? = nil) async -> Data {
        switch format {
        case .avif:
            // AVIF 压缩 - 使用 AVIFCompressor (FFmpeg)
            progressHandler?(0.3)
            print("🔄 [AVIF] 开始 AVIF 压缩 - 质量: \(quality)")
            
            if let result = await AVIFCompressor.compress(
                image: image,
                quality: Double(quality),
                speedPreset: settings.avifSpeedPreset,
                backend: settings.avifEncoderBackend,
                progressHandler: { progress in
                    // Map progress 0.3-1.0
                    let mappedProgress = 0.3 + (progress * 0.7)
                    progressHandler?(mappedProgress)
                }
            ) {
                progressHandler?(1.0)
                print("✅ [AVIF] 压缩成功 - 原始: \(result.originalSize) bytes, 压缩后: \(result.compressedSize) bytes")
                return result.data
            } else {
                print("⚠️ [AVIF] 压缩失败，回退到 JPEG")
                // AVIF 编码失败，回退到 JPEG
                if let jpegData = image.jpegData(compressionQuality: quality) {
                    progressHandler?(1.0)
                    print("✅ [AVIF->JPEG 回退] 压缩成功 - 大小: \(jpegData.count) bytes")
                    return jpegData
                }
                progressHandler?(1.0)
                return Data()
            }
            
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
            
            // 如果调整了分辨率，必须重新编码；否则使用原始 PNG 数据
            let pngDataToCompress: Data
            if resolutionChanged {
                print("📐 [PNG] 分辨率已调整，重新编码 PNG")
                pngDataToCompress = image.pngData() ?? Data()
            } else if let originalPNGData = originalPNGData {
                print("📐 [PNG] 分辨率未变，使用原始 PNG 数据")
                pngDataToCompress = originalPNGData
            } else {
                pngDataToCompress = image.pngData() ?? Data()
            }
            switch settings.pngCompressionTool {
            case .appleOptimized:
                let fallbackData: Data? = resolutionChanged ? nil : (pngDataToCompress.isEmpty ? nil : pngDataToCompress)
                if let result = await PNGCompressor.compressWithAppleOptimized(
                    image: image,
                    originalData: fallbackData,
                    progressHandler: { progress in
                        let mapped = 0.3 + (progress * 0.7)
                        progressHandler?(mapped)
                    }
                ) {
                    Self.lastPNGCompressionReport = result.report
                    print("✅ [PNG] Apple optimized success - size: \(result.data.count) bytes")
                    return result.data
                } else {
                    print("⚠️ [PNG] Apple optimized compressor failed, falling back to original PNG")
                    Self.lastPNGCompressionReport = nil
                    progressHandler?(1.0)
                    return image.pngData() ?? pngDataToCompress
                }
            case .zopfli:
                if let result = await PNGCompressor.compressWithOriginalData(
                    pngData: pngDataToCompress,
                    image: image,
                    numIterations: settings.pngNumIterations,
                    numIterationsLarge: settings.pngNumIterationsLarge,
                    lossyTransparent: settings.pngLossyTransparent,
                    lossy8bit: settings.pngLossy8bit,
                    progressHandler: { progress in
                        // 将 PNG 压缩器的进度映射到 0.3-1.0 范围
                        let mappedProgress = 0.3 + (progress * 0.7)
                        progressHandler?(mappedProgress)
                    }) {
                    Self.lastPNGCompressionReport = result.report
                    print("✅ [PNG] 压缩成功 - 大小: \(result.data.count) bytes")
                    return result.data
                } else {
                    print("⚠️ [PNG] 压缩失败，使用原始 PNG")
                    Self.lastPNGCompressionReport = nil
                    progressHandler?(1.0)
                    return image.pngData() ?? Data()
                }
            case .pngquant:
                let minQualityPercentRaw = Int((settings.pngQuantMinQuality * 100).rounded())
                let maxQualityPercentRaw = Int((settings.pngQuantMaxQuality * 100).rounded())
                let clampedMinQuality = max(0, min(100, minQualityPercentRaw))
                let clampedMaxQualityCandidate = max(0, min(100, maxQualityPercentRaw))
                let clampedMaxQuality = max(clampedMinQuality, clampedMaxQualityCandidate)
                if let result = await PNGCompressor.compressWithPNGQuant(
                    image: image,
                    qualityRange: (min: clampedMinQuality, max: clampedMaxQuality),
                    speed: settings.pngQuantSpeed,
                    progressHandler: { progress in
                        let mapped = 0.3 + (progress * 0.7)
                        progressHandler?(mapped)
                    }
                ) {
                    Self.lastPNGCompressionReport = result.report
                    print("✅ [PNG] pngquant success - size: \(result.data.count) bytes")
                    return result.data
                } else {
                    print("⚠️ [PNG] pngquant failed, falling back to original PNG")
                    Self.lastPNGCompressionReport = nil
                    progressHandler?(1.0)
                    return image.pngData() ?? Data()
                }
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
        originalBitDepth: Int? = nil,
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
            originalBitDepth: originalBitDepth,
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
