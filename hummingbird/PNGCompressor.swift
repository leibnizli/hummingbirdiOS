//
//  PNGCompressor.swift
//  hummingbird
//
//  PNG Compressor - Color quantization compression using system built-in methods
//

import UIKit
import pngquant

class PNGCompressor {
    
    /// Compress PNG image using pngquant
    /// - Parameters:
    ///   - image: Original image
    ///   - progressHandler: Progress callback (0.0 - 1.0)
    /// - Returns: Compressed PNG data
    static func compress(image: UIImage, progressHandler: ((Float) -> Void)? = nil) async -> Data? {
        progressHandler?(0.1)
        
        guard let cgImage = image.cgImage else {
            print("❌ [PNG Compression] Unable to get CGImage")
            return image.pngData()
        }
        
        // Check if alpha channel exists
        let hasAlpha = cgImage.alphaInfo != .none &&
                       cgImage.alphaInfo != .noneSkipFirst &&
                       cgImage.alphaInfo != .noneSkipLast
        
        // Get original PNG data for size comparison
        guard let originalPNGData = image.pngData() else {
            print("❌ [PNG Compression] Unable to convert to PNG data")
            return nil
        }
        
        let originalSize = originalPNGData.count
        print("🔄 [PNG Compression] Starting pngquant compression - Size: \(cgImage.width)x\(cgImage.height), Alpha: \(hasAlpha), Original size: \(originalSize) bytes")
        
        progressHandler?(0.3)
        
        do {
            // Use pngquant to compress the image
            // This uses the default quality settings (65-80)
            let compressedData = try image.pngQuantData()
            
            progressHandler?(0.8)
            
            let compressionRatio = Double(compressedData.count) / Double(originalSize)
            let savedBytes = originalSize - compressedData.count
            
            progressHandler?(1.0)
            
            // Check if compression actually reduced file size
            if compressedData.count >= originalSize {
                print("⚠️ [PNG Compression] Compressed size (\(compressedData.count) bytes) >= Original size (\(originalSize) bytes), keeping original")
                return originalPNGData
            }
            
            print("✅ [PNG Compression] pngquant compression complete - Compressed: \(compressedData.count) bytes, Ratio: \(String(format: "%.1f%%", compressionRatio * 100)), Saved: \(savedBytes) bytes")
            return compressedData
            
        } catch {
            print("❌ [PNG Compression] pngquant error: \(error.localizedDescription)")
            progressHandler?(1.0)
            
            // Fallback to original PNG data
            print("⚠️ [PNG Compression] Falling back to original PNG")
            return originalPNGData
        }
    }
}
