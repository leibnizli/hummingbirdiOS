//
//  PNGCompressor.swift
//  hummingbird
//
//  PNG Compressor - Color quantization compression using system built-in methods
import UIKit
import Darwin

struct PNGCompressionResult {
    let data: Data
    let actualLossyTransparent: Bool
    let actualLossy8bit: Bool
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

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {

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
                    return PNGCompressionResult(
                        data: out,
                        actualLossyTransparent: enableLossyTransparent,
                        actualLossy8bit: enableLossy8bit
                    )
                }

                continuation.resume(returning: result)
            }
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

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {

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
                    return PNGCompressionResult(
                        data: out,
                        actualLossyTransparent: enableLossyTransparent,
                        actualLossy8bit: enableLossy8bit
                    )
                }

                continuation.resume(returning: result)
            }
        }
    }
}
