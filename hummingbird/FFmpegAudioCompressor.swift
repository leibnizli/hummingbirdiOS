//
//  FFmpegAudioCompressor.swift
//  hummingbird
//
//  Audio compression using FFmpeg
//

import Foundation
import AVFoundation
import ffmpegkit

class FFmpegAudioCompressor {
    
    // Compress audio using FFmpeg
    static func compressAudio(
        inputURL: URL,
        outputURL: URL,
        settings: CompressionSettings,
        originalBitrate: Int?,
        originalSampleRate: Int?,
        originalChannels: Int?,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Get audio duration for progress calculation
        let asset = AVURLAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 智能参数调整：如果原始质量低于目标质量，保持原始参数
        let targetBitrate = settings.audioBitrate.bitrateValue
        let targetSampleRate = settings.audioSampleRate.sampleRateValue
        let targetChannels = settings.audioChannels.channelCount
        
        // 实际使用的参数（不会提升质量）
        let effectiveBitrate: Int
        if let originalBitrate = originalBitrate, originalBitrate > 0, originalBitrate < targetBitrate {
            // 原始比特率有效且低于目标，保持原始
            effectiveBitrate = originalBitrate
            print("🎵 [Audio] Original bitrate (\(originalBitrate) kbps) is lower than target (\(targetBitrate) kbps), keeping original")
        } else {
            // 原始比特率未知、无效(0)、或高于目标，使用目标比特率
            if originalBitrate == nil || originalBitrate == 0 {
                print("🎵 [Audio] Original bitrate is unknown or invalid, using target bitrate (\(targetBitrate) kbps)")
            } else {
                print("🎵 [Audio] Compressing from \(originalBitrate!) kbps to \(targetBitrate) kbps")
            }
            effectiveBitrate = targetBitrate
        }
        
        let effectiveSampleRate: Int
        if let originalSampleRate = originalSampleRate, originalSampleRate > 0, originalSampleRate < targetSampleRate {
            effectiveSampleRate = originalSampleRate
            print("🎵 [Audio] Original sample rate (\(originalSampleRate) Hz) is lower than target (\(targetSampleRate) Hz), keeping original")
        } else {
            effectiveSampleRate = targetSampleRate
        }
        
        let effectiveChannels: Int
        if let originalChannels = originalChannels, originalChannels > 0, originalChannels < targetChannels {
            effectiveChannels = originalChannels
            print("🎵 [Audio] Original channels (\(originalChannels)) is less than target (\(targetChannels)), keeping original")
        } else {
            effectiveChannels = targetChannels
        }
        
        // Generate FFmpeg command for MP3 compression
        let command = generateFFmpegCommand(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            bitrate: effectiveBitrate,
            sampleRate: effectiveSampleRate,
            channels: effectiveChannels
        )
        
        print("🎵 [FFmpeg Audio] Starting audio compression")
        print("📝 [FFmpeg Audio] Command: ffmpeg \(command)")
        print("⏱️ [FFmpeg Audio] Audio duration: \(duration) seconds")
        
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
                print("✅ [FFmpeg Audio] Compression successful")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "Unknown error"
                print("❌ [FFmpeg Audio] Compression failed")
                print("Error code: \(returnCode?.getValue() ?? -1)")
                
                // Only print last few lines of error to avoid long logs
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("Error message:\n\(errorLines)")
                
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "Audio compression failed, please check audio format or try other settings"])))
            }
        }, withLogCallback: { log in
            guard let log = log else { return }
            let message = log.getMessage() ?? ""
            
            // Only print errors and warnings
            let level = log.getLevel()
            if level <= 24 {  // AV_LOG_WARNING = 24
                print("[FFmpeg Audio Log] \(message)")
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
    
    // Generate FFmpeg command for audio compression
    private static func generateFFmpegCommand(
        inputPath: String,
        outputPath: String,
        bitrate: Int,
        sampleRate: Int,
        channels: Int
    ) -> String {
        var command = ""
        
        // Input file
        command += "-i \"\(inputPath)\""
        
        // Audio codec (libmp3lame for MP3)
        command += " -c:a libmp3lame"
        
        // Bitrate (use ABR mode for more predictable file size)
        command += " -b:a \(bitrate)k"
        
        // Sample rate
        command += " -ar \(sampleRate)"
        
        // Channels
        command += " -ac \(channels)"
        
        // Output file
        command += " \"\(outputPath)\""
        
        return command
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
}
