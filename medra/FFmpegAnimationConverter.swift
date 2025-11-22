//
//  FFmpegAnimationConverter.swift
//  hummingbird
//
//  Created by Agent on 2025/11/21.
//

import Foundation
import AVFoundation
import CoreMedia
import ffmpegkit

class FFmpegAnimationConverter {
    
    enum AnimationFormat: String {
        case webp
        case avif
        case gif
        
        var fileExtension: String {
            return self.rawValue
        }
    }
    
    static func convert(
        inputURL: URL,
        outputURL: URL,
        format: AnimationFormat,
        progressHandler: @escaping (Float) -> Void,
        frameCountHandler: ((Int) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        
        // Get video duration for progress calculation
        let asset = AVURLAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // Thread-safe state container
        class ConversionState: @unchecked Sendable {
            var hasCompleted = false
            let lock = NSLock()
        }
        let state = ConversionState()
        
        let safeCompletion: (Result<URL, Error>) -> Void = { result in
            state.lock.lock()
            defer { state.lock.unlock() }
            
            if !state.hasCompleted {
                state.hasCompleted = true
                completion(result)
            }
        }
        
        var command = ""
        
        switch format {
        case .webp:
            // ffmpeg -i input.mp4 -c:v libwebp -loop 0 -an output.webp
            // -an: disable audio
            // -loop 0: infinite loop
            // -preset default: default preset
            // -q:v 75: quality 75 (optional, can be adjusted)
            command = "-i \"\(inputPath)\" -c:v libwebp -loop 0 -an -preset default -q:v 75 \"\(outputPath)\""
            
        case .avif:
            // Direct AVIF conversion using FFmpeg with libaom-av1
            // This is the fastest method as it avoids intermediate files
            
            // First, detect frame count for user feedback
            Task.detached(priority: .userInitiated) {
                let frameCountCommand = "-v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 \"\(inputPath)\""
                let probeSession = FFprobeKit.execute(frameCountCommand)
                
                if let output = probeSession?.getOutput()?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let frameCount = Int(output), frameCount > 0 {
                    print("🎬 [FFmpeg Animation] Detected \(frameCount) frames")
                    // Notify UI about frame count
                    DispatchQueue.main.async {
                        frameCountHandler?(frameCount)
                    }
                }
                
                // Command to convert directly to AVIF
                // -c:v libaom-av1: Use AV1 codec
                // -cpu-used 8: Fastest encoding speed (0-8, 8 is fastest)
                // -crf 20: High quality (lower is better, typical range 15-35)
                // -f avif: Force AVIF format
                let command = "-i \"\(inputPath)\" -c:v libaom-av1 -cpu-used 8 -crf 20 -f avif \"\(outputPath)\""
                
                print("🎬 [FFmpeg Animation] Converting to AVIF")
                print("📝 [FFmpeg Animation] Command: ffmpeg \(command)")
                
                FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                    guard let session = session else {
                        safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session creation failed"])))
                        return
                    }
                    
                    let returnCode = session.getReturnCode()
                    
                    if ReturnCode.isSuccess(returnCode) {
                        print("✅ [FFmpeg Animation] AVIF conversion successful")
                        safeCompletion(.success(outputURL))
                    } else {
                        let errorMessage = session.getOutput() ?? "Unknown error"
                        print("❌ [FFmpeg Animation] AVIF conversion failed: \(errorMessage)")
                        safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "AVIF conversion failed: \(errorMessage)"])))
                    }
                }, withLogCallback: { log in
                    guard let log = log else { return }
                    let message = log.getMessage() ?? ""
                    
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
                    let time = Double(statistics.getTime()) / 1000.0
                    if duration > 0 {
                        let progress = Float(time / duration)
                        DispatchQueue.main.async {
                            progressHandler(min(progress, 0.99))
                        }
                    }
                })
            }
            
            return
            
        case .gif:
            // ffmpeg -i input.mp4 -vf "fps=15,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 output.gif
            // High quality GIF generation
            // For simplicity, we start with a basic command, but palettegen is better.
            // Let's use a decent quality command.
            command = "-i \"\(inputPath)\" -vf \"fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 \"\(outputPath)\""
        }
        
        print("🎬 [FFmpeg Animation] Starting conversion to \(format.rawValue)")
        print("📝 [FFmpeg Animation] Command: ffmpeg \(command)")
        
        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session creation failed"])))
                return
            }
            
            let returnCode = session.getReturnCode()
            
            if ReturnCode.isSuccess(returnCode) {
                print("✅ [FFmpeg Animation] Conversion successful")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "Unknown error"
                print("❌ [FFmpeg Animation] Conversion failed")
                print("Error code: \(returnCode?.getValue() ?? -1)")
                
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("Error message:\n\(errorLines)")
                
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "Conversion failed: \(errorMessage)"])))
            }
        }, withLogCallback: { log in
            guard let log = log else { return }
            let message = log.getMessage() ?? ""
            
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
}
