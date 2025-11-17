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
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("AVIF Quality")
                                Spacer()
                                Text("\(Int(settings.avifQuality * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.avifQuality, in: 0.1...1.0, step: 0.05)
                            
                            Text("Next-gen format with excellent compression. Requires iOS 16+ for native preview.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("AVIF Speed", selection: $settings.avifSpeedPreset) {
                                ForEach(AVIFSpeedPreset.allCases) { preset in
                                    Text(preset.rawValue).tag(preset)
                                }
                            }
                            Text(settings.avifSpeedPreset.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Preserve Animated WebP", isOn: $settings.preserveAnimatedWebP)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("When enabled, animated WebP files will be compressed while preserving all frames. When disabled, only the first frame will be kept (converted to static image).")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Text("Note: If the original is already highly optimized (lossless format), compression may result in a larger file size. In such cases, the original file will be automatically preserved.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Preserve Animated AVIF", isOn: $settings.preserveAnimatedAVIF)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("When enabled, AVIF image sequences keep their motion by re-encoding all frames. Turning it off flattens the sequence into a single still frame.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Re-encoding animations may take longer and some files may not shrink much if they are already optimized.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } header: {
                        Text("Quality Settings")
                    } footer: {
                        Text("Higher quality means larger file size. When HEIC is enabled, HEIC images will keep HEIC format; when disabled, MozJPEG will convert to JPEG format. WebP and AVIF formats will be compressed in original format. If compressed file is larger than original, the original will be kept automatically.")
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Compression Engine", selection: $settings.pngCompressionTool) {
                                ForEach(PNGCompressionTool.allCases) { tool in
                                    Text(tool.displayName).tag(tool)
                                }
                            }
                            Text(settings.pngCompressionTool.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if settings.pngCompressionTool == .zopfli {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Zopfli Iterations (Small Images)")
                                    Spacer()
                                    Text("\(settings.pngNumIterations)")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: Binding(
                                    get: { Double(settings.pngNumIterations) },
                                    set: { settings.pngNumIterations = Int($0) }
                                ), in: 1...5, step: 1)
                                Text("Used for images smaller than 1MB. Higher values = smaller file size, but slower compression. Default: 3 iterations.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Zopfli Iterations (Large Images)")
                                    Spacer()
                                    Text("\(settings.pngNumIterationsLarge)")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: Binding(
                                    get: { Double(settings.pngNumIterationsLarge) },
                                    set: { settings.pngNumIterationsLarge = Int($0) }
                                ), in: 1...3, step: 1)
                                Text("Used for images 1MB or larger. Usually set lower than small image iterations to balance compression vs time. Default: 1 iteration.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Allow Lossy Transparent Pixels", isOn: $settings.pngLossyTransparent)
                                Text("Only applies to images with alpha channel (transparency). Reduces file size by sacrificing transparency quality. Ignored for opaque images.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Convert 16-bit to 8-bit", isOn: $settings.pngLossy8bit)
                                Text("Only applies to 16-bit per channel images. Reduces precision to 8-bit, which reduces file size but may lose subtle color gradations. Ignored for standard 8-bit images.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("pngquant uses libimagequant to reduce the palette to 256 colors and applies perceptual dithering. This is ideal for UI assets, icons, and graphics with limited colors.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Tip: pngquant introduces a small amount of loss to shrink file size dramatically. Use Zopfli if you need strictly lossless output.")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Minimum Quality")
                                        Spacer()
                                        Text(String(format: "%.0f%%", settings.pngQuantMinQuality * 100))
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $settings.pngQuantMinQuality, in: 0.1...0.95, step: 0.05)
                                    Text("Lower bound for pngquant's perceptual quality range.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Maximum Quality")
                                        Spacer()
                                        Text(String(format: "%.0f%%", settings.pngQuantMaxQuality * 100))
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { settings.pngQuantMaxQuality },
                                            set: { newValue in settings.pngQuantMaxQuality = max(settings.pngQuantMinQuality, newValue) }
                                        ),
                                        in: settings.pngQuantMinQuality...1.0,
                                        step: 0.05
                                    )
                                    Text("Upper bound for pngquant's quality search. Higher values keep more detail at the cost of size.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Speed")
                                        Spacer()
                                        Text("\(settings.pngQuantSpeed)")
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: Binding(
                                        get: { Double(settings.pngQuantSpeed) },
                                        set: { settings.pngQuantSpeed = Int($0.rounded()) }
                                    ), in: 1...10, step: 1)
                                    Text("pngquant speed: 1 is slowest/best, 10 is fastest/lowest quality.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("PNG Compression Settings")
                    } footer: {
                        if settings.pngCompressionTool == .zopfli {
                            Text("Zopfli iterations: Higher values = better compression but slower. Lossy options can further reduce file size but may sacrifice quality. If lossy options don't apply to your image, they are automatically ignored.")
                        } else {
                            Text("pngquant outputs an indexed PNG. Colors are quantized to a smaller palette, which reduces size while preserving perceived detail.")
                        }
                    }
                    
                    // Open Source Libraries Notice
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            // JPEG Compression Library
                            VStack(alignment: .leading, spacing: 8) {
                                Text("JPEG Compression Library")
                                    .font(.headline)
                                
                                Text("Uses mozjpeg - Copyright (c) Mozilla Corporation. All rights reserved.")
                                    .font(.caption)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("PNG Compression Library")
                                    .font(.headline)
                                Text("pngquant (GPLv3) powered by libimagequant. Our integration code is published at https://github.com/leibnizli/hummingbirdiOS to satisfy GPL requirements.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Open Source Notice")
                    }
                }
                .navigationTitle("Image Compression Settings")
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
