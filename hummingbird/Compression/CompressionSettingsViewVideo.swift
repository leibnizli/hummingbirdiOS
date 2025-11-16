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
                // Content
                Form {
                    // Video Settings
                    Section {
                        // Target resolution
                        Picker("Target Resolution", selection: $settings.targetVideoResolution) {
                            ForEach(VideoResolution.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        
                        // Target orientation mode
                        if settings.targetVideoResolution != .original {
                            Picker("Target Orientation", selection: $settings.targetOrientationMode) {
                                ForEach(VideoOrientationMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            
                            // Explanation text
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
                        
                        // Target frame rate
                        Picker("Target Frame Rate", selection: $settings.frameRateMode) {
                            ForEach(FrameRateMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        // Custom frame rate slider
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
                        // Video codec
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Video Codec", selection: $settings.videoCodec) {
                                ForEach(VideoCodec.allCases) { codec in
                                    Text(codec.rawValue).tag(codec)
                                }
                            }
                            
                            Text(settings.videoCodec.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Quality preset
//                        Picker("Encoding Speed", selection: $settings.videoQualityPreset) {
//                            ForEach(VideoQualityPreset.allCases) { preset in
//                                Text(preset.rawValue).tag(preset)
//                            }
//                        }
//                        
//                        // CRF quality mode
//                        Picker("Quality Level", selection: $settings.crfQualityMode) {
//                            ForEach(CRFQualityMode.allCases) { mode in
//                                Text(mode.rawValue).tag(mode)
//                            }
//                        }
//                        
//                        // Custom CRF
//                        if settings.crfQualityMode == .custom {
//                            VStack(alignment: .leading, spacing: 8) {
//                                HStack {
//                                    Text("CRF Value")
//                                    Spacer()
//                                    Text("\(settings.customCRF)")
//                                        .foregroundStyle(.secondary)
//                                }
//                                Slider(value: Binding(
//                                    get: { Double(settings.customCRF) },
//                                    set: { settings.customCRF = Int($0) }
//                                ), in: 0...51, step: 1)
//                                
//                                Text("Lower CRF value means better quality but larger file size. Recommended range: 18-28")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
                        
                        // Hardware decode acceleration
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Hardware Decode Acceleration", isOn: $settings.useHardwareAcceleration)
                            
                            Text("Use hardware acceleration to decode input video, improves processing speed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Codec & Quality")
                    } footer: {
                        Text("H.265 provides higher compression ratio but requires more processing time. CRF mode (recommended) provides stable quality. Slower encoding speed results in better compression.")
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
