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
    
    var body: some View {
        NavigationView {
            Form {
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
                    Text("Image Compression")
                } footer: {
                    Text("Higher quality means larger file size, maintains original resolution. When HEIC is enabled, HEIC images will keep HEIC format; when disabled, MozJPEG will convert to JPEG format. WebP format will be compressed in original format. If compressed file is larger, original will be kept automatically")
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
                    Text("Video Compression (FFmpeg)")
                } footer: {
                    Text("H.265 provides higher compression ratio but requires more processing time. CRF mode (recommended) provides stable quality. Slower encoding speed results in better compression.")
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
