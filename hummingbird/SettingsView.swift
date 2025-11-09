//
//  SettingsView.swift
//  hummingbird
//
//  设置视图
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: CompressionSettings
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("优先使用 HEIC", isOn: $settings.preferHEIC)
                    
                    if settings.preferHEIC {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("HEIC 质量")
                                Spacer()
                                Text("\(Int(settings.heicQuality * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.heicQuality, in: 0.1...1.0, step: 0.05)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("JPEG 质量")
                            Spacer()
                            Text("\(Int(settings.jpegQuality * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.jpegQuality, in: 0.1...1.0, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("WebP 质量")
                            Spacer()
                            Text("\(Int(settings.webpQuality * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.webpQuality, in: 0.1...1.0, step: 0.05)
                    }
                } header: {
                    Text("图片压缩")
                } footer: {
                    Text("质量越高文件越大，保持原始分辨率。开启 HEIC 后，HEIC 图片将保持 HEIC 格式；关闭后将使用 MozJPEG 转换为 JPEG 格式。WebP 格式会保持原格式压缩。如果压缩后文件反而变大，会自动保留原图")
                }
                
                Section {
                    // 视频编码器
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("视频编码器", selection: $settings.videoCodec) {
                            ForEach(VideoCodec.allCases) { codec in
                                Text(codec.rawValue).tag(codec)
                            }
                        }
                        
                        Text(settings.videoCodec.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 质量预设
                    Picker("编码速度", selection: $settings.videoQualityPreset) {
                        ForEach(VideoQualityPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    
                    // CRF 质量模式
                    Picker("质量等级", selection: $settings.crfQualityMode) {
                        ForEach(CRFQualityMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    // 自定义 CRF
                    if settings.crfQualityMode == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("CRF 值")
                                Spacer()
                                Text("\(settings.customCRF)")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(settings.customCRF) },
                                set: { settings.customCRF = Int($0) }
                            ), in: 0...51, step: 1)
                            
                            Text("CRF 值越小质量越好，文件越大。推荐范围：18-28")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 硬件解码加速
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("硬件解码加速", isOn: $settings.useHardwareAcceleration)
                        
                        Text("使用硬件加速解码输入视频，提升处理速度")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                } header: {
                    Text("视频压缩 (FFmpeg)")
                } footer: {
                    Text("H.265提供更高压缩率但需要更多处理时间。可以选择CRF模式（推荐）获得稳定质量。编码速度越慢，压缩效果越好。")
                }
            }
            .navigationTitle("压缩设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
