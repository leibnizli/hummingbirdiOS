//
//  CompressionSettingsView.swift
//  hummingbird
//
//  Settings View
//

import SwiftUI

struct CompressionSettingsViewVideo: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: CompressionSettings
    @State private var selectedCategory: SettingsCategory = .video
    
    enum SettingsCategory: String, CaseIterable {
        case video = "Video"
        case audio = "Audio"
        case image = "Image"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Picker("Target Resolution", selection: $settings.targetVideoResolution) {
                            ForEach(VideoResolution.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        
                        if settings.targetVideoResolution != .original {
                            Picker("Target Orientation", selection: $settings.targetOrientationMode) {
                                ForEach(VideoOrientationMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if settings.targetOrientationMode == .auto {
                                    Text("Auto: Target resolution will match the original video's orientation")
                                } else if settings.targetOrientationMode == .landscape {
                                    Text("Landscape: Target resolution will be in landscape format (e.g., 1920×1080)")
                                } else {
                                    Text("Portrait: Target resolution will be in portrait format (e.g., 1080×1920)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Picker("Target Frame Rate", selection: $settings.frameRateMode) {
                            ForEach(FrameRateMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        if settings.frameRateMode == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Custom Frame Rate")
                                    Spacer()
                                    Text("\(settings.customFrameRate) fps")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: Binding(
                                    get: { Double(settings.customFrameRate) },
                                    set: { settings.customFrameRate = Int($0) }
                                ), in: 15...120, step: 1)
                            }
                        }
                    } header: {
                        Text("Resolution & Frame Rate")
                    } footer: {
                        if settings.targetVideoResolution != .original {
                            Text("Video will be scaled down proportionally if original resolution is larger than target. Frame rate will only be reduced if target is lower than original.")
                        } else {
                            Text("Frame rate will only be reduced if target is lower than original.")
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Video Codec", selection: $settings.videoCodec) {
                                ForEach(VideoCodec.allCases) { codec in
                                    Text(codec.rawValue).tag(codec)
                                }
                            }
                            
                            Text(settings.videoCodec.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("WebM (VP8/VP9) sources are always re-encoded to the selected codec (e.g., H.264/HEVC) and saved as MP4 during compression. This process takes longer than compressing H.264/HEVC sources.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Dolby Vision (DVHE/DVH1) sources keep the original video stream to preserve metadata; the app only adjusts the container when needed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Automatic Bitrate", isOn: $settings.useAutoBitrate)
                                .font(.headline)
                            
                            if settings.useAutoBitrate {
                                Text("Hardware bitrate is derived from the target resolution: 720p≈1.5 Mbps, 1080p≈3 Mbps, 2K≈5 Mbps, 4K≈8 Mbps. If you keep the original resolution, we estimate using the source dimensions.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Custom Bitrate")
                                        Spacer()
                                        Text("\(settings.customVideoBitrate) kbps")
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: Binding(
                                        get: { Double(settings.customVideoBitrate) },
                                        set: { settings.customVideoBitrate = Int($0) }
                                    ), in: 500...15000, step: 100)
                                    Text("Custom bitrate for VideoToolbox hardware encoder (500-15000 kbps). Higher values preserve more detail but increase file size.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Codec & Quality")
                    } footer: {
                        Text("Higher bitrates improve detail at the cost of larger files. H.265 stays smaller than H.264 but encodes more slowly.")
                    }
                }
                .navigationTitle("Video Compression Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
