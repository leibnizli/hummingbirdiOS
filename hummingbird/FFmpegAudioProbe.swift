//
//  FFmpegAudioProbe.swift
//  hummingbird
//
//  Audio metadata detection using FFmpeg
//

import Foundation
import AVFoundation
import ffmpegkit

// 注意：ffmpegkit 包含了 FFprobeKit

class FFmpegAudioProbe {
    
    // 音频探测结果
    struct AudioInfo {
        var bitrate: Int?           // kbps
        var sampleRate: Int?        // Hz
        var channels: Int?          // 1=mono, 2=stereo
        var duration: Double?       // seconds
        var codec: String?          // mp3, aac, flac, etc.
        var format: String?         // container format
        var bitrateMode: String?    // CBR, VBR, or nil
    }
    
    /// 使用 FFmpeg 探测音频文件信息
    /// - Parameter url: 音频文件 URL
    /// - Returns: 音频信息，如果探测失败返回 nil
    static func probeAudioFile(at url: URL) async -> AudioInfo? {
        print("🔍 [FFmpeg Probe] 开始探测音频文件: \(url.lastPathComponent)")
        print("🔍 [FFmpeg Probe] 文件路径: \(url.path)")
        
        // 构建 ffprobe 命令
        // -v error: 只显示错误信息
        // -print_format json: 输出 JSON 格式
        // -show_format: 显示容器格式信息
        // -show_streams: 显示流信息
        let command = "-v error -print_format json -show_format -show_streams \"\(url.path)\""
        
        print("🔍 [FFmpeg Probe] 执行命令: ffprobe \(command)")
        
        return await withCheckedContinuation { continuation in
            // 注意：使用 FFprobeKit 而不是 FFmpegKit
            FFprobeKit.executeAsync(command, withCompleteCallback: { session in
                guard let session = session else {
                    print("❌ [FFmpeg Probe] Session 创建失败")
                    continuation.resume(returning: nil)
                    return
                }
                
                let returnCode = session.getReturnCode()
                
                if ReturnCode.isSuccess(returnCode) {
                    // 获取输出
                    guard let output = session.getOutput(), !output.isEmpty else {
                        print("❌ [FFmpeg Probe] 输出为空")
                        
                        // 尝试获取错误日志
                        if let logs = session.getAllLogsAsString() {
                            print("📋 [FFmpeg Probe] 日志: \(logs)")
                        }
                        
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    print("📋 [FFmpeg Probe] 收到输出，长度: \(output.count) 字符")
                    
                    // 解析 JSON
                    if let audioInfo = parseFFmpegOutput(output) {
                        print("✅ [FFmpeg Probe] 探测成功")
                        print("   比特率: \(audioInfo.bitrate ?? 0) kbps")
                        print("   采样率: \(audioInfo.sampleRate ?? 0) Hz")
                        print("   声道: \(audioInfo.channels ?? 0)")
                        print("   编码: \(audioInfo.codec ?? "unknown")")
                        print("   时长: \(String(format: "%.2f", audioInfo.duration ?? 0)) 秒")
                        if let mode = audioInfo.bitrateMode {
                            print("   比特率模式: \(mode)")
                        }
                        continuation.resume(returning: audioInfo)
                    } else {
                        print("❌ [FFmpeg Probe] JSON 解析失败")
                        print("📋 [FFmpeg Probe] 原始输出前 500 字符:")
                        print(String(output.prefix(500)))
                        continuation.resume(returning: nil)
                    }
                } else {
                    print("❌ [FFmpeg Probe] 探测失败，错误码: \(returnCode?.getValue() ?? -1)")
                    
                    // 打印详细的错误信息
                    if let output = session.getOutput() {
                        print("📋 [FFmpeg Probe] 标准输出:")
                        print(output)
                    }
                    
                    if let allLogs = session.getAllLogsAsString() {
                        print("📋 [FFmpeg Probe] 完整日志:")
                        print(allLogs)
                    }
                    
                    continuation.resume(returning: nil)
                }
            })
        }
    }
    
    /// 解析 FFmpeg 输出的 JSON
    private static func parseFFmpegOutput(_ output: String) -> AudioInfo? {
        guard let data = output.data(using: .utf8) else {
            print("❌ [FFmpeg Probe] 无法转换输出为 Data")
            return nil
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [FFmpeg Probe] JSON 根对象不是字典")
                return nil
            }
            
            var audioInfo = AudioInfo()
            
            // 解析 format 信息（容器级别）
            if let format = json["format"] as? [String: Any] {
                // 时长
                if let durationStr = format["duration"] as? String,
                   let duration = Double(durationStr) {
                    audioInfo.duration = duration
                }
                
                // 容器格式
                if let formatName = format["format_name"] as? String {
                    audioInfo.format = formatName
                }
                
                // 整体比特率（作为回退）
                if let bitrateStr = format["bit_rate"] as? String,
                   let bitrate = Int(bitrateStr) {
                    audioInfo.bitrate = bitrate / 1000  // 转换为 kbps
                }
            }
            
            // 解析 streams 信息（流级别，更准确）
            if let streams = json["streams"] as? [[String: Any]] {
                // 找到第一个音频流
                for stream in streams {
                    if let codecType = stream["codec_type"] as? String,
                       codecType == "audio" {
                        
                        // 编码格式
                        if let codecName = stream["codec_name"] as? String {
                            audioInfo.codec = codecName
                        }
                        
                        // 比特率（流级别，优先使用）
                        if let bitrateStr = stream["bit_rate"] as? String,
                           let bitrate = Int(bitrateStr) {
                            audioInfo.bitrate = bitrate / 1000  // 转换为 kbps
                        }
                        
                        // 采样率
                        if let sampleRateStr = stream["sample_rate"] as? String,
                           let sampleRate = Int(sampleRateStr) {
                            audioInfo.sampleRate = sampleRate
                        }
                        
                        // 声道数
                        if let channels = stream["channels"] as? Int {
                            audioInfo.channels = channels
                        }
                        
                        // 比特率模式（如果有）
                        if let tags = stream["tags"] as? [String: Any] {
                            if let mode = tags["MODE"] as? String {
                                audioInfo.bitrateMode = mode
                            }
                        }
                        
                        // 找到音频流后退出
                        break
                    }
                }
            }
            
            return audioInfo
            
        } catch {
            print("❌ [FFmpeg Probe] JSON 解析错误: \(error)")
            return nil
        }
    }
    
    /// 便捷方法：只获取比特率
    static func detectBitrate(at url: URL) async -> Int? {
        guard let info = await probeAudioFile(at: url) else {
            return nil
        }
        return info.bitrate
    }
    
    /// 便捷方法：获取完整的音频元数据（包含 AVFoundation 检测不到的信息）
    static func getEnhancedAudioMetadata(at url: URL) async -> (bitrate: Int?, sampleRate: Int?, channels: Int?, duration: Double?, codec: String?) {
        guard let info = await probeAudioFile(at: url) else {
            return (nil, nil, nil, nil, nil)
        }
        return (info.bitrate, info.sampleRate, info.channels, info.duration, info.codec)
    }
    
    /// 回退方案：通过文件大小和时长计算平均比特率
    static func calculateAverageBitrate(fileURL: URL, duration: Double) -> Int? {
        guard duration > 0 else {
            print("⚠️ [FFmpeg Probe] 时长无效，无法计算比特率")
            return nil
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let fileSize = attributes[.size] as? Int, fileSize > 0 else {
                print("⚠️ [FFmpeg Probe] 无法获取文件大小")
                return nil
            }
            
            // 比特率 (kbps) = (文件大小 (bytes) × 8) / (时长 (秒) × 1000)
            let bitrate = (fileSize * 8) / (Int(duration) * 1000)
            print("📊 [FFmpeg Probe] 计算平均比特率: \(bitrate) kbps (文件大小: \(fileSize) bytes, 时长: \(String(format: "%.2f", duration)) 秒)")
            return bitrate
        } catch {
            print("❌ [FFmpeg Probe] 获取文件属性失败: \(error)")
            return nil
        }
    }
}
