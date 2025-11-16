//
//  FFmpegVideoCompressor.swift
//  hummingbird
//
//  Video compression using FFmpeg
//

import Foundation
import AVFoundation
import ffmpegkit

class FFmpegVideoCompressor {
    
    // Compress video using FFmpeg
    static func compressVideo(
        inputURL: URL,
        outputURL: URL,
        settings: CompressionSettings,
        originalFrameRate: Double? = nil,
        originalResolution: CGSize? = nil,
        originalBitDepth: Int? = nil,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Get video duration for progress calculation
        let asset = AVURLAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // Generate FFmpeg command
        let command = settings.generateFFmpegCommand(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            videoSize: originalResolution,
            originalFrameRate: originalFrameRate,
            originalBitDepth: originalBitDepth
        )
        
        print("🎬 [FFmpeg] Starting video compression")
        print("📝 [FFmpeg] Command: ffmpeg \(command)")
        print("⏱️ [FFmpeg] Video duration: \(duration) seconds")
        
        // Use flag to ensure completion is only called once
        var hasCompleted = false
        let completionLock = NSLock()
        
        let safeCompletion: (Result<URL, Error>) -> Void = { result in
            completionLock.lock()
            defer { completionLock.unlock() }
            
            if !hasCompleted {
                hasCompleted = true
                completion(result)
            }
        }
        
        // Execute FFmpeg command
        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session creation failed"])))
                return
            }
            
            let returnCode = session.getReturnCode()
            
            if ReturnCode.isSuccess(returnCode) {
                print("✅ [FFmpeg] Compression successful")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "Unknown error"
                print("❌ [FFmpeg] Compression failed")
                print("Error code: \(returnCode?.getValue() ?? -1)")
                
                // Only print last few lines of error to avoid long logs
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("Error message:\n\(errorLines)")
                
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "Video compression failed, please check video format or try other settings"])))
            }
        }, withLogCallback: { log in
            guard let log = log else { return }
            let message = log.getMessage() ?? ""
            
            // Only print errors and warnings (lower level values are more important, 24=warning, 16=error)
            let level = log.getLevel()
            if level <= 24 {  // AV_LOG_WARNING = 24
                print("[FFmpeg Log] \(message)")
            }
            
            // Parse progress information
            if message.contains("time=") {
                if let timeRange = message.range(of: "time=([0-9:.]+)", options: .regularExpression) {
                    let timeString = String(message[timeRange]).replacingOccurrences(of: "time=", with: "")
                    if let currentTime = parseTimeString(timeString), duration > 0 {
                        let progress = Float(currentTime / duration)
                        DispatchQueue.main.async {
                            progressHandler(min(progress, 0.99))
                        }
                    }
                }
            }
        }, withStatisticsCallback: { statistics in
            guard let statistics = statistics else { return }
            
            // Calculate progress using statistics
            let time = Double(statistics.getTime()) / 1000.0  // Convert to seconds
            if duration > 0 {
                let progress = Float(time / duration)
                DispatchQueue.main.async {
                    progressHandler(min(progress, 0.99))
                }
            }
        })
    }
    
    // Parse time string (HH:MM:SS.ms)
    private static func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.split(separator: ":")
        guard components.count == 3 else { return nil }
        
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    // Cancel ongoing compression
    static func cancelAllSessions() {
        FFmpegKit.cancel()
    }

    // Copy input file streams (audio/video) to specified container (no re-encoding), for quick container/extension change
    static func remux(
        inputURL: URL,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        let outputExtension = outputURL.pathExtension.lowercased()

        // Check source video encoding format
        let asset = AVURLAsset(url: inputURL)
        var isHEVC = false
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let formatDescriptions = videoTrack.formatDescriptions as! [CMFormatDescription]
            if let formatDescription = formatDescriptions.first {
                let codecType = CMFormatDescriptionGetMediaSubType(formatDescription)
                // HEVC codec type is 'hvc1' or 'hev1'
                isHEVC = (codecType == kCMVideoCodecType_HEVC || 
                         codecType == kCMVideoCodecType_HEVCWithAlpha)
            }
        }
        
        // If output is M4V and source is HEVC, cannot use remux (M4V doesn't support HEVC)
        if outputExtension == "m4v" && isHEVC {
            print("⚠️ [FFmpeg Remux] M4V doesn't support HEVC encoding, remux failed")
            completion(.failure(NSError(domain: "FFmpeg", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "M4V container doesn't support HEVC encoding, re-encoding required"])))
            return
        }

        // -c copy means directly copy streams, avoid re-encoding
        let command = "-i \"\(inputPath)\" -map 0 -c copy -map_metadata 0 -movflags +faststart \"\(outputPath)\""

        print("🎬 [FFmpeg Remux] Starting remux")
        print("📝 [FFmpeg Remux] Command: ffmpeg \(command)")

        var hasCompleted = false
        let completionLock = NSLock()
        let safeCompletion: (Result<URL, Error>) -> Void = { result in
            completionLock.lock()
            defer { completionLock.unlock() }
            if !hasCompleted {
                hasCompleted = true
                completion(result)
            }
        }

        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session creation failed"])))
                return
            }

            let returnCode = session.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                print("✅ [FFmpeg Remux] Success: \(outputPath)")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "Unknown error"
                print("❌ [FFmpeg Remux] Failed: \(String(describing: returnCode?.getValue()))")
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("Error message:\n\(errorLines)")
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "Remux failed"])))
            }
        }, withLogCallback: { _ in }, withStatisticsCallback: { _ in })
    }

    static func extractThumbnail(
        from inputURL: URL,
        at second: Double = 1.0,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let inputPath = inputURL.path
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("thumb_\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        let outputPath = outputURL.path

        // Remove existing file if any
        try? FileManager.default.removeItem(atPath: outputPath)

        // Clamp seek position to non-negative values
        let seekTime = max(0.0, second)
        let seekParameter = String(format: "%.3f", seekTime)

        let command = "-hide_banner -ss \(seekParameter) -i \"\(inputPath)\" -map 0:v:0 -frames:v 1 -q:v 2 -y \"\(outputPath)\""

        var hasCompleted = false
        let completionLock = NSLock()
        let safeCompletion: (Result<URL, Error>) -> Void = { result in
            completionLock.lock()
            defer { completionLock.unlock() }
            if !hasCompleted {
                hasCompleted = true
                completion(result)
            }
        }

        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session creation failed"])))
                return
            }

            let returnCode = session.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "Unknown error"
                print("❌ [FFmpeg Thumbnail] Failed\n\(errorMessage)")
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "Thumbnail extraction failed"])))
            }
        }, withLogCallback: { _ in }, withStatisticsCallback: { _ in })
    }
}

