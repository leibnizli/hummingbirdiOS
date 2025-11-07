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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("图片质量")
                            Spacer()
                            Text("\(Int(settings.imageQuality * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.05)
                    }
                } header: {
                    Text("图片压缩")
                } footer: {
                    Text("质量越高文件越大，保持原始分辨率")
                }
                
                Section {
                    // 比特率控制
                    Picker("比特率控制", selection: $settings.bitrateControlMode) {
                        ForEach(BitrateControlMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // 自动模式：显示说明
                    if settings.bitrateControlMode == .auto {
                        Text("根据视频分辨率自动计算最佳比特率，确保文件变小")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 手动模式：显示比特率滑块
                    if settings.bitrateControlMode == .manual {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("目标比特率")
                                Spacer()
                                Text(String(format: "%.1f Mbps", settings.customBitrate))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settings.customBitrate, in: 0.5...20.0, step: 0.5)
                            
                            HStack(spacing: 4) {
                                Text("参考：")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("720p: 2-5 Mbps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("1080p: 5-10 Mbps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("视频压缩")
                } footer: {
                    Text("保持原始分辨率，根据比特率设置调整文件大小")
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
