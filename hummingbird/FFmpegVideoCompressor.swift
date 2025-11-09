//
//  FFmpegVideoCompressor.swift
//  hummingbird
//
//  使用 FFmpeg 进行视频压缩
//

import Foundation
import AVFoundation
import ffmpegkit

class FFmpegVideoCompressor {
    
    // 使用 FFmpeg 压缩视频
    static func compressVideo(
        inputURL: URL,
        outputURL: URL,
        settings: CompressionSettings,
        progressHandler: @escaping (Float) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 获取视频时长用于计算进度
        let asset = AVURLAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 生成 FFmpeg 命令
        let command = settings.generateFFmpegCommand(
            inputPath: inputURL.path,
            outputPath: outputURL.path
        )
        
        print("🎬 [FFmpeg] 开始压缩视频")
        print("📝 [FFmpeg] 命令: ffmpeg \(command)")
        print("⏱️ [FFmpeg] 视频时长: \(duration) 秒")
        
        // 使用标志确保 completion 只被调用一次
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
        
        // 执行 FFmpeg 命令
        FFmpegKit.executeAsync(command, withCompleteCallback: { session in
            guard let session = session else {
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "会话创建失败"])))
                return
            }
            
            let returnCode = session.getReturnCode()
            
            if ReturnCode.isSuccess(returnCode) {
                print("✅ [FFmpeg] 压缩成功")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "未知错误"
                print("❌ [FFmpeg] 压缩失败")
                print("错误码: \(returnCode?.getValue() ?? -1)")
                
                // 只打印最后几行错误信息，避免日志过长
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("错误信息:\n\(errorLines)")
                
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "视频压缩失败，请检查视频格式或尝试其他设置"])))
            }
        }, withLogCallback: { log in
            guard let log = log else { return }
            let message = log.getMessage() ?? ""
            
            // 只打印错误和警告信息（level 值越小越重要，24=warning, 16=error）
            let level = log.getLevel()
            if level <= 24 {  // AV_LOG_WARNING = 24
                print("[FFmpeg Log] \(message)")
            }
            
            // 解析进度信息
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
            
            // 使用统计信息计算进度
            let time = Double(statistics.getTime()) / 1000.0  // 转换为秒
            if duration > 0 {
                let progress = Float(time / duration)
                DispatchQueue.main.async {
                    progressHandler(min(progress, 0.99))
                }
            }
        })
    }
    
    // 解析时间字符串 (HH:MM:SS.ms)
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
    
    // 取消正在进行的压缩
    static func cancelAllSessions() {
        FFmpegKit.cancel()
    }

    // 将输入文件的流（音视频）拷贝到指定容器（无重新编码），用于快速改变容器/扩展名
    static func remux(
        inputURL: URL,
        outputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let inputPath = inputURL.path
        let outputPath = outputURL.path

        // -c copy 表示直接拷贝流，避免重新编码
        let command = "-i \"\(inputPath)\" -c copy -movflags +faststart \"\(outputPath)\""

        print("🎬 [FFmpeg Remux] 开始 remux")
        print("📝 [FFmpeg Remux] 命令: ffmpeg \(command)")

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
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: -1, userInfo: [NSLocalizedDescriptionKey: "会话创建失败"])))
                return
            }

            let returnCode = session.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                print("✅ [FFmpeg Remux] 成功: \(outputPath)")
                safeCompletion(.success(outputURL))
            } else {
                let errorMessage = session.getOutput() ?? "未知错误"
                print("❌ [FFmpeg Remux] 失败: \(String(describing: returnCode?.getValue()))")
                let lines = errorMessage.split(separator: "\n")
                let errorLines = lines.suffix(10).joined(separator: "\n")
                print("错误信息:\n\(errorLines)")
                safeCompletion(.failure(NSError(domain: "FFmpeg", code: Int(returnCode?.getValue() ?? -1), userInfo: [NSLocalizedDescriptionKey: "remux 失败"])))
            }
        }, withLogCallback: { _ in }, withStatisticsCallback: { _ in })
    }
}

