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
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let inputPath = inputURL.path
        let outputPath = outputURL.path
        
        // Get video duration for progress calculation
        let asset = AVURLAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
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
            // ffmpeg -i input.mp4 -c:v libaom-av1 -still-picture 0 -an output.avif
            // Note: standard ffmpeg might use libaom-av1 or librav1e. 
            // The user suggested: ffmpeg -i 1.mp4 -pix_fmt yuv420p -f yuv4mpegpipe output.y4m && avifenc output.y4m animated.avif
            // Since we are using ffmpeg-kit, we try to use what's available. 
            // We'll try a standard command first. If libaom-av1 is not available, this might fail.
            // -strict experimental might be needed for some encoders.
            command = "-i \"\(inputPath)\" -c:v libaom-av1 -strict experimental -pix_fmt yuv420p -an \"\(outputPath)\""
            
        case .gif:
            // ffmpeg -i input.mp4 -vf "fps=15,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 output.gif
            // High quality GIF generation
            // For simplicity, we start with a basic command, but palettegen is better.
            // Let's use a decent quality command.
            command = "-i \"\(inputPath)\" -vf \"fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0 \"\(outputPath)\""
        }
        
        print("🎬 [FFmpeg Animation] Starting conversion to \(format.rawValue)")
        print("📝 [FFmpeg Animation] Command: ffmpeg \(command)")
        
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
