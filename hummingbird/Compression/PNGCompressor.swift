//
//  PNGCompressor.swift
//  hummingbird
//
//  PNG Compressor - Color quantization compression using system built-in methods
import UIKit
import Darwin

typealias liq_result = OpaquePointer

struct PNGCompressionResult {
    let data: Data
    let report: PNGCompressionReport
}

struct PNGCompressor { }

extension PNGCompressor {

    /// Compress PNG using original PNG data (not re-encoded from UIImage)
    /// This preserves the original PNG structure for better compression.
    /// Only uses UIImage for property detection (alpha, bit depth).
    static func compressWithOriginalData(
        pngData: Data,
        image: UIImage,
        numIterations: Int = 15,
        numIterationsLarge: Int = 15,
        lossyTransparent: Bool = false,
        lossy8bit: Bool = false,
        progressHandler: ((Float) -> Void)? = nil) async -> PNGCompressionResult? {

        guard !pngData.isEmpty else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PNGCompressionResult?, Never>) in
            let workItem = DispatchWorkItem {

                let result: PNGCompressionResult? = pngData.withUnsafeBytes { (origBuf: UnsafeRawBufferPointer) -> PNGCompressionResult? in
                    guard let base = origBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                    var options = CZopfliPNGOptions()
                    CZopfliPNGSetDefaults(&options)

                    // Apply compression settings
                    options.num_iterations = Int32(numIterations)
                    options.num_iterations_large = Int32(numIterationsLarge)
                    
                    // Set filter strategies: --filters=0me (None, MinSum, Entropy)
                    // 0 = kStrategyZero, 5 = kStrategyMinSum, 6 = kStrategyEntropy
                    var strategies: [ZopfliPNGFilterStrategy] = [
                        ZopfliPNGFilterStrategy(rawValue: 0),  // kStrategyZero
                        ZopfliPNGFilterStrategy(rawValue: 5),  // kStrategyMinSum
                        ZopfliPNGFilterStrategy(rawValue: 6)   // kStrategyEntropy
                    ]
                    let strategiesPtr = UnsafeMutablePointer<ZopfliPNGFilterStrategy>.allocate(capacity: strategies.count)
                    strategiesPtr.initialize(from: strategies, count: strategies.count)
                    options.filter_strategies = strategiesPtr
                    options.num_filter_strategies = Int32(strategies.count)

                    // Detect image properties to avoid enabling lossy options that don't apply
                    let cg = image.cgImage
                    let bitsPerComponent = cg?.bitsPerComponent ?? 8
                    let alphaInfo = cg?.alphaInfo
                    let hasAlpha: Bool
                    if let ai = alphaInfo {
                        hasAlpha = !(ai == .none || ai == .noneSkipLast || ai == .noneSkipFirst)
                    } else {
                        hasAlpha = false
                    }

                    // Only enable lossy transparent if image actually has alpha
                    let enableLossyTransparent = lossyTransparent && hasAlpha
                    if lossyTransparent && !hasAlpha {
                        print("ℹ️ PNGCompressor: lossy_transparent disabled (image has no alpha channel)")
                    }

                    // Only enable lossy 8bit if source is >8 bits per component
                    let enableLossy8bit = lossy8bit && bitsPerComponent > 8
                    if lossy8bit && bitsPerComponent <= 8 {
                        print("ℹ️ PNGCompressor: lossy_8bit disabled (image is already \(bitsPerComponent)-bit, not 16-bit)")
                    }

                    options.lossy_transparent = enableLossyTransparent ? 1 : 0
                    options.lossy_8bit = enableLossy8bit ? 1 : 0
                    options.use_zopfli = 1  // Always use Zopfli for best compression
                    
                    // Log all applied options for debugging
                    print("🔧 PNGCompressor CZopfliPNGOptions (compressWithOriginalData):")
                    print("  num_iterations: \(options.num_iterations)")
                    print("  num_iterations_large: \(options.num_iterations_large)")
                    print("  lossy_transparent: \(options.lossy_transparent)")
                    print("  lossy_8bit: \(options.lossy_8bit)")
                    print("  use_zopfli: \(options.use_zopfli)")
                    print("  filter_strategies: 0me (None, MinSum, Entropy)")
                    print("  num_filter_strategies: \(options.num_filter_strategies)")

                    var resultPtr: UnsafeMutablePointer<UInt8>? = nil
                    var resultSize: size_t = 0

                    let ret = CZopfliPNGOptimize(base,
                                                 size_t(origBuf.count),
                                                 &options,
                                                 0,
                                                 &resultPtr,
                                                 &resultSize)
                    
                    // Free filter strategies memory
                    options.filter_strategies?.deallocate()

                    guard ret == 0, let rptr = resultPtr, resultSize > 0 else {
                        return nil
                    }

                    let buffer = UnsafeBufferPointer(start: rptr, count: Int(resultSize))
                    let out = Data(buffer: buffer)

                    free(rptr)
                    
                    // Return both data and actual applied lossy flags
                    let report = PNGCompressionReport(
                        tool: .zopfli,
                        zopfliIterations: numIterations,
                        zopfliIterationsLarge: numIterationsLarge,
                        lossyTransparent: enableLossyTransparent,
                        lossy8bit: enableLossy8bit,
                        paletteSize: nil,
                        quantizationQuality: nil
                    )

                    return PNGCompressionResult(data: out, report: report)
                }

                continuation.resume(returning: result)
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    /// Compress a UIImage using libimagequant (pngquant) style color quantization.
    /// Produces an indexed palette image and re-encodes it as PNG data.
    static func compressWithPNGQuant(
        image: UIImage,
        qualityRange: (min: Int, max: Int) = (60, 95),
        speed: Int = 3,
        dithering: Float = 1.0,
        progressHandler: ((Float) -> Void)? = nil
    ) async -> PNGCompressionResult? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PNGCompressionResult?, Never>) in
            let workItem = DispatchWorkItem {
                progressHandler?(0.05)

                let bytesPerPixel = 4
                let bytesPerRow = width * bytesPerPixel
                var rgbaBuffer = [UInt8](repeating: 0, count: bytesPerRow * height)
                let colorSpace = CGColorSpaceCreateDeviceRGB()

                guard let context = CGContext(
                    data: &rgbaBuffer,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ) else {
                    continuation.resume(returning: nil)
                    return
                }

                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

                guard let attr = liq_attr_create() else {
                    continuation.resume(returning: nil)
                    return
                }
                defer { liq_attr_destroy(attr) }

                _ = liq_set_speed(attr, Int32(speed))
                _ = liq_set_quality(attr, Int32(qualityRange.min), Int32(qualityRange.max))

                var compressionResult: PNGCompressionResult?

                rgbaBuffer.withUnsafeMutableBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress else { return }
                    guard let liqImagePtr = liq_image_create_rgba(attr, baseAddress, Int32(width), Int32(height), 0.0) else {
                        return
                    }
                    defer { liq_image_destroy(liqImagePtr) }

                    _ = liq_image_set_memory_ownership(liqImagePtr, Int32(LIQ_COPY_PIXELS.rawValue))

                    var resultPtr: liq_result? = nil
                    let quantStatus = liq_image_quantize(liqImagePtr, attr, &resultPtr)
                    guard quantStatus == LIQ_OK, let quantResult = resultPtr else {
                        return
                    }
                    defer { liq_result_destroy(quantResult) }

                    _ = liq_set_dithering_level(quantResult, dithering)

                    let pixelCount = width * height
                    var remappedPixels = [UInt8](repeating: 0, count: pixelCount)
                    let remapStatus = liq_write_remapped_image(quantResult, liqImagePtr, &remappedPixels, remappedPixels.count)
                    guard remapStatus == LIQ_OK, let palettePtr = liq_get_palette(quantResult) else {
                        return
                    }

                    let palette = palettePtr.pointee
                    let paletteCount = Int(palette.count)
                    guard paletteCount > 0 else { return }

                    progressHandler?(0.6)

                    var quantizedRGBA = [UInt8](repeating: 0, count: pixelCount * bytesPerPixel)
                    withUnsafePointer(to: palette.entries) { tuplePtr in
                        tuplePtr.withMemoryRebound(to: liq_color.self, capacity: 256) { entriesPtr in
                            for index in 0..<pixelCount {
                                let paletteIndex = Int(remappedPixels[index])
                                guard paletteIndex < paletteCount else { continue }
                                let color = entriesPtr[paletteIndex]
                                let dst = index * bytesPerPixel
                                quantizedRGBA[dst] = color.r
                                quantizedRGBA[dst + 1] = color.g
                                quantizedRGBA[dst + 2] = color.b
                                quantizedRGBA[dst + 3] = color.a
                            }
                        }
                    }

                    guard let provider = CGDataProvider(data: Data(quantizedRGBA) as CFData) else {
                        return
                    }

                    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                    guard let quantizedCGImage = CGImage(
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bitsPerPixel: 32,
                        bytesPerRow: bytesPerRow,
                        space: colorSpace,
                        bitmapInfo: bitmapInfo,
                        provider: provider,
                        decode: nil,
                        shouldInterpolate: false,
                        intent: .defaultIntent
                    ) else {
                        return
                    }

                    let quantizedImage = UIImage(cgImage: quantizedCGImage, scale: image.scale, orientation: image.imageOrientation)
                    guard let pngData = quantizedImage.pngData() else {
                        return
                    }

                    let qualityScore = liq_get_quantization_quality(quantResult)
                    let report = PNGCompressionReport(
                        tool: .pngquant,
                        zopfliIterations: nil,
                        zopfliIterationsLarge: nil,
                        lossyTransparent: nil,
                        lossy8bit: nil,
                        paletteSize: paletteCount,
                        quantizationQuality: Int(qualityScore)
                    )

                    compressionResult = PNGCompressionResult(data: pngData, report: report)
                }

                progressHandler?(1.0)
                continuation.resume(returning: compressionResult)
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    /// Compress a UIImage using the C API `CZopfliPNGOptimize`.
    /// Uses the in-memory C API with configurable zopflipng options.
    /// Returns both compressed data and actual applied lossy flags (after validation checks).
    static func compress(image: UIImage,
                         numIterations: Int = 15,
                         numIterationsLarge: Int = 15,
                         lossyTransparent: Bool = false,
                         lossy8bit: Bool = false,
                         progressHandler: ((Float) -> Void)? = nil) async -> PNGCompressionResult? {

        guard let pngData = image.pngData() else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PNGCompressionResult?, Never>) in
            let workItem = DispatchWorkItem {

                let result: PNGCompressionResult? = pngData.withUnsafeBytes { (origBuf: UnsafeRawBufferPointer) -> PNGCompressionResult? in
                    guard let base = origBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                    var options = CZopfliPNGOptions()
                    CZopfliPNGSetDefaults(&options)

                    // Apply compression settings
                    options.num_iterations = Int32(numIterations)
                    options.num_iterations_large = Int32(numIterationsLarge)
                    
                    // Set filter strategies: --filters=0me (None, MinSum, Entropy)
                    // 0 = kStrategyZero, 5 = kStrategyMinSum, 6 = kStrategyEntropy
                    var strategies: [ZopfliPNGFilterStrategy] = [
                        ZopfliPNGFilterStrategy(rawValue: 0),  // kStrategyZero
                        ZopfliPNGFilterStrategy(rawValue: 5),  // kStrategyMinSum
                        ZopfliPNGFilterStrategy(rawValue: 6)   // kStrategyEntropy
                    ]
                    let strategiesPtr = UnsafeMutablePointer<ZopfliPNGFilterStrategy>.allocate(capacity: strategies.count)
                    strategiesPtr.initialize(from: strategies, count: strategies.count)
                    options.filter_strategies = strategiesPtr
                    options.num_filter_strategies = Int32(strategies.count)

                    // Detect image properties to avoid enabling lossy options that don't apply
                    let cg = image.cgImage
                    let bitsPerComponent = cg?.bitsPerComponent ?? 8
                    let alphaInfo = cg?.alphaInfo
                    let hasAlpha: Bool
                    if let ai = alphaInfo {
                        hasAlpha = !(ai == .none || ai == .noneSkipLast || ai == .noneSkipFirst)
                    } else {
                        hasAlpha = false
                    }

                    // Only enable lossy transparent if image actually has alpha
                    let enableLossyTransparent = lossyTransparent && hasAlpha
                    if lossyTransparent && !hasAlpha {
                        print("ℹ️ PNGCompressor: lossy_transparent disabled (image has no alpha channel)")
                    }

                    // Only enable lossy 8bit if source is >8 bits per component
                    let enableLossy8bit = lossy8bit && bitsPerComponent > 8
                    if lossy8bit && bitsPerComponent <= 8 {
                        print("ℹ️ PNGCompressor: lossy_8bit disabled (image is already \(bitsPerComponent)-bit, not 16-bit)")
                    }

                    options.lossy_transparent = enableLossyTransparent ? 1 : 0
                    options.lossy_8bit = enableLossy8bit ? 1 : 0
                    options.use_zopfli = 1  // Always use Zopfli for best compression
                    
                    // Log all applied options for debugging
                    print("🔧 PNGCompressor CZopfliPNGOptions (compress):")
                    print("  num_iterations: \(options.num_iterations)")
                    print("  num_iterations_large: \(options.num_iterations_large)")
                    print("  lossy_transparent: \(options.lossy_transparent)")
                    print("  lossy_8bit: \(options.lossy_8bit)")
                    print("  use_zopfli: \(options.use_zopfli)")
                    print("  filter_strategies: 0me (None, MinSum, Entropy)")
                    print("  num_filter_strategies: \(options.num_filter_strategies)")

                    var resultPtr: UnsafeMutablePointer<UInt8>? = nil
                    var resultSize: size_t = 0

                    let ret = CZopfliPNGOptimize(base,
                                                 size_t(origBuf.count),
                                                 &options,
                                                 0,
                                                 &resultPtr,
                                                 &resultSize)
                    
                    // Free filter strategies memory
                    options.filter_strategies?.deallocate()

                    guard ret == 0, let rptr = resultPtr, resultSize > 0 else {
                        return nil
                    }

                    let buffer = UnsafeBufferPointer(start: rptr, count: Int(resultSize))
                    let out = Data(buffer: buffer)

                    free(rptr)
                    
                    // Return both data and actual applied lossy flags
                    let report = PNGCompressionReport(
                        tool: .zopfli,
                        zopfliIterations: numIterations,
                        zopfliIterationsLarge: numIterationsLarge,
                        lossyTransparent: enableLossyTransparent,
                        lossy8bit: enableLossy8bit,
                        paletteSize: nil,
                        quantizationQuality: nil
                    )

                    return PNGCompressionResult(data: out, report: report)
                }

                continuation.resume(returning: result)
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }
}
