//
//  AudioTrimView.swift
//  medra
//
//  Created by admin on 2025/11/23.
//

import SwiftUI
import AVFoundation

struct AudioTrimView: View {
    let audioURL: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerManager = AudioPlayerManager.shared
    
    // Trimming State
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var duration: Double = 0
    @State private var waveformSamples: [Float] = []
    @State private var isProcessing: Bool = false
    @State private var showSaveSuccess: Bool = false
    
    // New Features State
    @State private var fadeInDuration: Double = 0
    @State private var fadeOutDuration: Double = 0
    @State private var selectedFormat: AudioFormat = .original
    @State private var showSettings = false
    
    // UI State
    @State private var sliderWidth: CGFloat = 0
    @State private var dragStartTimes: (start: Double, end: Double)? = nil
    
    // Zoom/Pan State
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGFloat = 0
    @State private var lastPanOffset: CGFloat = 0
    
    private let waveformHeight: CGFloat = 200
    private let handleWidth: CGFloat = 20
    
    // Unique ID for this view's playback session
    private let playbackID = UUID()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: {
                        playerManager.stop()
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Trim Audio")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveTrimmedAudio()
                    }
                    .foregroundColor(.yellow)
                    .disabled(isProcessing)
                }
                .padding()
                
                Spacer()
                
                // Main Content
                VStack(spacing: 30) {
                    // Time Display
                    HStack(spacing: 40) {
                        VStack {
                            Text("Start")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(startTime))
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Duration")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(endTime - startTime))
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundColor(.yellow)
                        }
                        
                        VStack {
                            Text("End")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatTime(endTime))
                                .font(.title2)
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Waveform & Slider
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background Waveform
                            WaveformView(samples: waveformSamples)
                                .frame(height: waveformHeight)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                            
                            // Dimmed Areas (outside selection)
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: max(0, timeToWidth(startTime, width: geometry.size.width)))
                                
                                Spacer()
                                
                                Rectangle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: max(0, geometry.size.width - timeToWidth(endTime, width: geometry.size.width)))
                            }
                            
                            // Selection Border
                            Rectangle()
                                .strokeBorder(Color.yellow, lineWidth: 3)
                                .frame(width: max(0, timeToWidth(endTime, width: geometry.size.width) - timeToWidth(startTime, width: geometry.size.width)))
                                .offset(x: timeToWidth(startTime, width: geometry.size.width))
                            
                            // Playhead (White line)
                            if playerManager.isCurrentAudio(itemId: playbackID) {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 3, height: waveformHeight)
                                    .offset(x: timeToWidth(playerManager.currentTime, width: geometry.size.width) - 1.5)
                            }
                            
                            // Start Handle (Higher z-index)
                            TrimHandle(time: $startTime, 
                                     otherTime: endTime,
                                     duration: duration,
                                     width: geometry.size.width,
                                     isStart: true,
                                     onSeek: seekTo)
                            
                            // End Handle (Higher z-index)
                            TrimHandle(time: $endTime,
                                     otherTime: startTime,
                                     duration: duration,
                                     width: geometry.size.width,
                                     isStart: false,
                                     onSeek: seekTo)
                            
                            // Tap to seek gesture (lowest priority)
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let time = widthToTime(value.location.x, width: geometry.size.width)
                                            seekTo(time)
                                        }
                                )
                        }
                        .frame(height: waveformHeight)
                        .onAppear {
                            sliderWidth = geometry.size.width
                        }
                    }
                    .frame(height: waveformHeight)
                    .padding(.horizontal)
                    
                    // Current Time Display
                    if playerManager.isCurrentAudio(itemId: playbackID) {
                        Text(formatTime(playerManager.currentTime))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.white)
                    }
                    
                    // Playback Controls
                    HStack(spacing: 40) {
                        Button(action: {
                            seekTo(startTime)
                        }) {
                            Image(systemName: "backward.end.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: togglePlayback) {
                            Image(systemName: playerManager.isPlaying(itemId: playbackID) ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Settings Sheet
            if showSettings {
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showSettings = false }
                
                VStack(spacing: 20) {
                    Text("Export Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Format")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Picker("Format", selection: $selectedFormat) {
                            Text("Original").tag(AudioFormat.original)
                            Text("MP3").tag(AudioFormat.mp3)
                            Text("M4A").tag(AudioFormat.m4a)
                            Text("WAV").tag(AudioFormat.wav)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fade In")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.1f", fadeInDuration))s")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        Slider(value: $fadeInDuration, in: 0...5, step: 0.5)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fade Out")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.1f", fadeOutDuration))s")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                        Slider(value: $fadeOutDuration, in: 0...5, step: 0.5)
                    }
                    .padding(.horizontal)
                    
                    Button("Done") {
                        showSettings = false
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(16)
                .padding()
            }
            
            if isProcessing {
                Color.black.opacity(0.8).edgesIgnoringSafeArea(.all)
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Saving...")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            playerManager.stop()
        }
        .alert("Saved Successfully", isPresented: $showSaveSuccess) {
            Button("OK") { dismiss() }
        }
    }
    
    // MARK: - Logic
    
    private func loadAudio() {
        let asset = AVAsset(url: audioURL)
        duration = CMTimeGetSeconds(asset.duration)
        endTime = duration
        generateWaveform()
    }
    
    private func generateWaveform() {
        waveformSamples = (0..<100).map { _ in Float.random(in: 0.2...1.0) }
    }
    
    private func togglePlayback() {
        playerManager.togglePlayPause(itemId: playbackID, audioURL: audioURL)
        
        if playerManager.currentTime >= endTime || playerManager.currentTime < startTime {
            seekTo(startTime)
        }
    }
    
    private func seekTo(_ time: Double) {
        let clampedTime = min(max(0, time), duration)
        playerManager.seek(to: clampedTime)
    }
    
    private func saveTrimmedAudio() {
        isProcessing = true
        playerManager.stop()
        
        let ext = selectedFormat == .original ? audioURL.pathExtension : selectedFormat.fileExtension
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString)")
            .appendingPathExtension(ext)
        
        FFmpegAudioCompressor.trimAudio(
            inputURL: audioURL,
            outputURL: outputURL,
            startTime: startTime,
            endTime: endTime,
            fadeIn: fadeInDuration,
            fadeOut: fadeOutDuration,
            outputFormat: selectedFormat
        ) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success(let url):
                    saveToDocuments(url)
                case .failure(let error):
                    print("Error trimming: \(error)")
                }
            }
        }
    }
    
    private func saveToDocuments(_ tempURL: URL) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let trimmedFolder = documents.appendingPathComponent("TrimmedAudio")
        
        do {
            try FileManager.default.createDirectory(at: trimmedFolder, withIntermediateDirectories: true)
            let destination = trimmedFolder.appendingPathComponent(tempURL.lastPathComponent)
            
            try FileManager.default.moveItem(at: tempURL, to: destination)
            showSaveSuccess = true
            
        } catch {
            print("Error saving file: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1) * 100))
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
    
    private func timeToWidth(_ time: Double, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }
    
    private func widthToTime(_ width: CGFloat, width totalWidth: CGFloat) -> Double {
        guard totalWidth > 0 else { return 0 }
        return Double(width / totalWidth) * duration
    }
}

// Separate handle component with its own gesture
struct TrimHandle: View {
    @Binding var time: Double
    let otherTime: Double  // The other handle's time (for bounds checking)
    let duration: Double
    let width: CGFloat
    let isStart: Bool
    let onSeek: (Double) -> Void
    
    private let handleWidth: CGFloat = 24
    private let handleHeight: CGFloat = 60
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.yellow)
            .frame(width: handleWidth, height: handleHeight)
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                }
            )
            .shadow(radius: 3)
            .offset(x: timeToWidth(time) - handleWidth / 2)
            .offset(y: (200 - handleHeight) / 2) // Center vertically
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = timeToWidth(time) + value.translation.width
                        let newTime = widthToTime(newX)
                        
                        if isStart {
                            // Start handle: can't go past end handle or duration
                            time = min(max(0, newTime), otherTime - 0.5)
                        } else {
                            // End handle: can't go before start handle or 0
                            time = max(min(duration, newTime), otherTime + 0.5)
                        }
                        onSeek(time)
                    }
            )
    }
    
    private func timeToWidth(_ time: Double) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }
    
    private func widthToTime(_ width: CGFloat) -> Double {
        guard self.width > 0 else { return 0 }
        return Double(width / self.width) * duration
    }
}

struct HandleView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.yellow)
            .frame(width: 20, height: 60)
            .overlay(
                VStack(spacing: 4) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                }
            )
            .shadow(radius: 2)
    }
}

struct WaveformView: View {
    let samples: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<samples.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.yellow.opacity(0.7))
                        .frame(width: geometry.size.width / CGFloat(samples.count),
                               height: CGFloat(samples[index]) * geometry.size.height * 0.8)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
