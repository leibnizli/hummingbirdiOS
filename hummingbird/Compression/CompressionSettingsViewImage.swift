//
//  CompressionSettingsView.swift
//  hummingbird
//
//  Settings View
//

import SwiftUI

struct CompressionSettingsViewImage: View {
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
