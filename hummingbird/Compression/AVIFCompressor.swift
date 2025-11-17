//
//  AVIFCompressor.swift
//  hummingbird
//
//  AVIF Image Compressor using FFmpeg with libaom-av1
//

import Foundation
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
        progressHandler: ((Float) -> Void)? = nil
    ) async -> AVIFCompressionResult? {
        
        progressHandler?(0.05)
        
        // Get PNG representation of source image (preserve alpha)
        guard let sourceData = image.pngData() else {
            print("❌ [AVIF] Failed to get PNG data from source image")
            return nil
        }
        
        let originalSize = sourceData.count
        
        // Create temporary files
        let tempDir = FileManager.default.temporaryDirectory
        let inputURL = tempDir.appendingPathComponent(UUID().uuidString + ".png")
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".avif")
        
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Write source to temp file
        do {
            try sourceData.write(to: inputURL)
        } catch {
            print("❌ [AVIF] Failed to write temp input file: \(error)")
            return nil
        }
        
        progressHandler?(0.2)
        
        // Map quality (0.1-1.0) to CRF (63-10)
        // Higher quality → lower CRF
        let crf = calculateCRF(from: quality)
        let cpuUsed = speedPreset.cpuUsedValue
        
        // Build FFmpeg command
        let command = """
        -i "\(inputURL.path)" \
        -c:v libaom-av1 \
        -crf \(crf) \
        -cpu-used \(cpuUsed) \
        -still-picture 1 \
        -pix_fmt yuv420p \
        "\(outputURL.path)"
        """
        
        print("🎨 [AVIF] Encoding with quality=\(Int(quality * 100))% (CRF \(crf)), speed=\(speedPreset.rawValue) (cpu-used \(cpuUsed))")
        print("🔧 [AVIF] FFmpeg command: ffmpeg \(command)")
        
        progressHandler?(0.3)
        
        // Execute FFmpeg
        let session = FFmpegKit.execute(command)
        
        guard let returnCode = session?.getReturnCode(), ReturnCode.isSuccess(returnCode) else {
            let output = session?.getOutput() ?? "Unknown error"
            print("❌ [AVIF] FFmpeg encoding failed: \(output)")
            return nil
        }
        
        progressHandler?(0.9)
        
        // Read compressed output
        guard let compressedData = try? Data(contentsOf: outputURL) else {
            print("❌ [AVIF] Failed to read compressed AVIF file")
            return nil
        }
        
        let compressedSize = compressedData.count
        let compressionRatio = Double(compressedSize) / Double(originalSize)
        
        print("✅ [AVIF] Compression successful")
        print("   Original: \(originalSize) bytes")
        print("   Compressed: \(compressedSize) bytes")
        print("   Ratio: \(String(format: "%.1f%%", compressionRatio * 100))")
        
        progressHandler?(1.0)
        
        return AVIFCompressionResult(
            data: compressedData,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
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
}
