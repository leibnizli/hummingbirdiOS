//
//  CompressionSettingsView.swift
//  hummingbird
//
//  Settings View
//

import SwiftUI

struct CompressionSettingsViewAudio: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: CompressionSettings
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {                
                // Content
                Form {
                    // Audio Settings
                    Section {
                        Picker("Output Format", selection: $settings.audioFormat) {
                            ForEach(AudioFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                    } header: {
                        Text("Format Settings")
                    } footer: {
                        Text("Choose the output audio format. Original keeps the same format as input file. MP3 and AAC are widely compatible. OPUS offers better quality at lower bitrates. FLAC is lossless. WAV is uncompressed.")
                    }
                    
                    Section {
                        Picker("Bitrate", selection: $settings.audioBitrate) {
                            ForEach(AudioBitrate.allCases) { bitrate in
                                Text(bitrate.rawValue).tag(bitrate)
                            }
                        }
                        .disabled(settings.audioFormat == .flac || settings.audioFormat == .wav)
                        
                        Picker("Sample Rate", selection: $settings.audioSampleRate) {
                            ForEach(AudioSampleRate.allCases) { sampleRate in
                                Text(sampleRate.rawValue).tag(sampleRate)
                            }
                        }
                        
                        Picker("Channels", selection: $settings.audioChannels) {
                            ForEach(AudioChannels.allCases) { channels in
                                Text(channels.rawValue).tag(channels)
                            }
                        }
                    } header: {
                        Text("Audio Quality Settings")
                    } footer: {
                        if settings.audioFormat == .original {
                            Text("Original format keeps the same format as input file. Quality settings will still apply to reduce file size while maintaining the original format.")
                        } else if settings.audioFormat == .flac {
                            Text("FLAC is lossless compression, bitrate setting is not applicable. Original quality will be preserved.")
                        } else if settings.audioFormat == .wav {
                            Text("WAV is uncompressed PCM audio, bitrate setting is not applicable.")
                        } else {
                            Text("If the original audio quality is lower than the target settings, the original quality will be preserved to avoid unnecessary file size increase. For example, if the original audio is 128 kbps and you set 320 kbps, it will remain at 128 kbps.")
                        }
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Smart Quality Protection")
                                .font(.headline)
                            
                            Text("The app automatically detects the original audio quality and prevents upsampling:")
                                .font(.subheadline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("Bitrate: Won't increase from low to high (e.g., 128 kbps → 320 kbps)")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("Sample Rate: Won't increase from low to high (e.g., 44.1 kHz → 48 kHz)")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("Channels: Won't convert mono to stereo")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                            Text("This ensures optimal file size without fake quality improvement.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("How It Works")
                    }
                }
                .navigationTitle("Compression Audio Settings")
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
