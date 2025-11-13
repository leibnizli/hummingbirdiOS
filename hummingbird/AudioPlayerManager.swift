//
//  AudioPlayerManager.swift
//  hummingbird
//
//  音频播放管理器 - 确保同时只有一个音频在播放
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    @Published var currentPlayingItemId: UUID?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    private override init() {
        super.init()
        // 配置音频会话
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AudioPlayer] 配置音频会话失败: \(error)")
        }
    }
    
    // 播放或暂停音频
    func togglePlayPause(itemId: UUID, audioURL: URL) {
        // 如果点击的是当前正在播放的音频
        if currentPlayingItemId == itemId {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }
        
        // 停止当前播放的音频
        stop()
        
        // 播放新的音频
        play(itemId: itemId, audioURL: audioURL)
    }
    
    private func play(itemId: UUID, audioURL: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.delegate = self
            player?.prepareToPlay()
            
            if player?.play() == true {
                currentPlayingItemId = itemId
                isPlaying = true
                duration = player?.duration ?? 0
                startTimer()
                print("▶️ [AudioPlayer] 开始播放: \(itemId)")
            }
        } catch {
            print("❌ [AudioPlayer] 播放失败: \(error)")
        }
    }
    
    private func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        print("⏸️ [AudioPlayer] 暂停播放")
    }
    
    private func resume() {
        if player?.play() == true {
            isPlaying = true
            startTimer()
            print("▶️ [AudioPlayer] 继续播放")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentPlayingItemId = nil
        currentTime = 0
        duration = 0
        stopTimer()
        print("⏹️ [AudioPlayer] 停止播放")
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        currentTime = player?.currentTime ?? 0
    }
    
    // 检查某个音频是否正在播放
    func isPlaying(itemId: UUID) -> Bool {
        return currentPlayingItemId == itemId && isPlaying
    }
    
    // 获取播放进度（0.0 到 1.0）
    func getProgress(for itemId: UUID) -> Double {
        guard currentPlayingItemId == itemId, duration > 0 else {
            return 0
        }
        return currentTime / duration
    }
    
    // 检查某个音频是否是当前音频（播放中或暂停）
    func isCurrentAudio(itemId: UUID) -> Bool {
        return currentPlayingItemId == itemId
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            print("✅ [AudioPlayer] 播放完成")
            stop()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ [AudioPlayer] 解码错误: \(error?.localizedDescription ?? "Unknown")")
            stop()
        }
    }
}
