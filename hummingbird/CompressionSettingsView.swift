//
//  CompressionSettingsView.swift
//  hummingbird
//
//  Settings View
//

import SwiftUI

struct CompressionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: CompressionSettings
    @State private var selectedCategory: SettingsCategory = .video
    
    enum SettingsCategory: String, CaseIterable {
        case video = "Video"
        case image = "Image"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented Control
                Picker("Category", selection: $selectedCategory) {
                    ForEach(SettingsCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                Form {
                if selectedCategory == .image {
                    // Image Settings
                    Section {
                        // Target resolution
                        Picker("Target Resolution", selection: $settings.targetImageResolution) {
                            ForEach(ImageResolutionTarget.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        
                        // Target orientation mode
                        if settings.targetImageResolution != .original {
                            Picker("Target Orientation", selection: $settings.targetImageOrientationMode) {
                                ForEach(OrientationMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            
                            // Explanation text
                            VStack(alignment: .leading, spacing: 4) {
                                if settings.targetImageOrientationMode == .auto {
                                    Text("Auto: Target resolution will match the original image's orientation")
                                } else if settings.targetImageOrientationMode == .landscape {
                                    Text("Landscape: Target resolution will be in landscape format (e.g., 1920×1080)")
                                } else {
                                    Text("Portrait: Target resolution will be in portrait format (e.g., 1080×1920)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Resolution Settings")
                    } footer: {
                        if settings.targetImageResolution != .original {
                            Text("Image will be scaled down proportionally if original resolution is larger than target")
                        } else {
                            Text("Original resolution will be maintained")
                        }
                    }
                    
                    Section {
                        Toggle("Prefer HEIC", isOn: $settings.preferHEIC)
                        
                        if settings.preferHEIC {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("HEIC Quality")
                                    Spacer()
                                    Text("\(Int(settings.heicQuality * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $settings.heicQuality, in: 0.1...1.0, step: 0.05)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("JPEG Quality")
                                Spacer()
                                Text("\(Int(settings.jpegQuality * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.05)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("WebP Quality")
                                Spacer()
                                Text("\(Int(settings.webpQuality * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.webpQuality, in: 0.1...1.0, step: 0.05)
                        }
                    } header: {
                        Text("Quality Settings")
                    } footer: {
                        Text("Higher quality means larger file size, maintains original resolution. When HEIC is enabled, HEIC images will keep HEIC format; when disabled, MozJPEG will convert to JPEG format. WebP format will be compressed in original format. If compressed file is larger, original will be kept automatically")
                    }
                    
                    // Open Source Libraries Notice
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            // PNG Compression Library
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PNG Compression Library")
                                    .font(.headline)
                                
                                Text("This app uses pngquant.swift for PNG compression, which is licensed under the GNU Lesser General Public License v3.0 (LGPL-3.0).")
                                    .font(.caption)
                                
                                Text("The library source code has not been modified.")
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Link("Source Code: pngquant.swift", destination: URL(string: "https://github.com/awxkee/pngquant.swift")!)
                                        .font(.caption)
                                    
                                    Link("LGPL-3.0 License", destination: URL(string: "https://www.gnu.org/licenses/lgpl-3.0.txt")!)
                                        .font(.caption)
                                    
                                    Link("GNU GPL v3", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.txt")!)
                                        .font(.caption)
                                }
                                
                                Text("For library replacement or to obtain object files for relinking, please contact: stormte@gmail.com")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                            
                            // JPEG Compression Library
                            VStack(alignment: .leading, spacing: 8) {
                                Text("JPEG Compression Library")
                                    .font(.headline)
                                
                                Text("Uses mozjpeg - Copyright (c) Mozilla Corporation. All rights reserved.")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Open Source Notice")
                    }
                } else {
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
                        Picker("Encoding Speed", selection: $settings.videoQualityPreset) {
                            ForEach(VideoQualityPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        
                        // CRF quality mode
                        Picker("Quality Level", selection: $settings.crfQualityMode) {
                            ForEach(CRFQualityMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        
                        // Custom CRF
                        if settings.crfQualityMode == .custom {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("CRF Value")
                                    Spacer()
                                    Text("\(settings.customCRF)")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: Binding(
                                    get: { Double(settings.customCRF) },
                                    set: { settings.customCRF = Int($0) }
                                ), in: 0...51, step: 1)
                                
                                Text("Lower CRF value means better quality but larger file size. Recommended range: 18-28")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
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
                }
                .navigationTitle("Compression Settings")
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
