//
//  FFmpegWebPCompressor.swift
//  medra
//
//  Created by Agent on 2025/11/23.
//

import Foundation
import ffmpegkit

class FFmpegWebPCompressor {
    
    /// Compress animated WebP data using FFmpeg
    /// - Parameters:
    ///   - data: Original WebP data
    ///   - settings: Compression settings
    ///   - progressHandler: Progress callback (0.0 - 1.0)
    /// - Returns: Compressed WebP data, or nil if failed
    static func compress(
        data: Data,
        settings: CompressionSettings,
        progressHandler: ((Float) -> Void)? = nil
    ) async -> Data? {
        // 1. Write data to temporary input file
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueID = UUID().uuidString
        let inputURL = tempDir.appendingPathComponent("input_\(uniqueID).webp")
        let outputURL = tempDir.appendingPathComponent("output_\(uniqueID).webp")
        
        do {
            try data.write(to: inputURL)
        } catch {
            print("❌ [FFmpeg WebP] Failed to write input file: \(error)")
            return nil
        }
        
        // Ensure cleanup
        defer {
            try? FileManager.default.removeItem(at: inputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // 2. Prepare FFmpeg command
        // Quality mapping: 0.0-1.0 -> 0-100
        let quality = Int(max(0, min(100, settings.webpQuality * 100)))
        
        // Command explanation:
        // -i input: Input file
        // -c:v libwebp: Use WebP encoder
        // -lossless 0: Lossy compression
        // -q:v quality: Quality factor (0-100)
        // -preset default: Default preset
        // -loop 0: Infinite loop (preserve animation)
        // -an: Remove audio
        // -vsync 0: Passthrough timestamps (important for animation timing)
        let command = "-i \"\(inputURL.path)\" -r 15 -c:v libwebp -lossless 0 -q:v \(quality) -preset default -loop 0 -an -vsync 0 \"\(outputURL.path)\""
        
        print("🎬 [FFmpeg WebP] Starting compression")
        print("📝 [FFmpeg WebP] Command: ffmpeg \(command)")
        
        // 3. Execute FFmpeg command
        return await withCheckedContinuation { continuation in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session = session else {
                    print("❌ [FFmpeg WebP] Session creation failed")
                    continuation.resume(returning: nil)
                    return
                }
                
                let returnCode = session.getReturnCode()
                
                if ReturnCode.isSuccess(returnCode) {
                    print("✅ [FFmpeg WebP] Compression successful")
                    
                    // Read output file
                    do {
                        let compressedData = try Data(contentsOf: outputURL)
                        print("📊 [FFmpeg WebP] Original: \(data.count) -> Compressed: \(compressedData.count)")
                        continuation.resume(returning: compressedData)
                    } catch {
                        print("❌ [FFmpeg WebP] Failed to read output file: \(error)")
                        continuation.resume(returning: nil)
                    }
                } else {
                    let errorMessage = session.getOutput() ?? "Unknown error"
                    print("❌ [FFmpeg WebP] Compression failed: \(errorMessage)")
                    continuation.resume(returning: nil)
                }
            }, withLogCallback: { log in
                // Optional: Parse log for progress if needed
                // For WebP re-encoding, progress is hard to estimate without knowing total frames/duration beforehand
                // We can just send some indeterminate progress or keep it simple
            }, withStatisticsCallback: { statistics in
                // If we knew the duration, we could calculate progress
                // For now, we just let it run
            })
        }
    }
}
