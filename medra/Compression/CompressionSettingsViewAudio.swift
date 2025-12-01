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
                        // Format selection removed, always use original format
                        HStack {
                            Text("Output Format")
                            Spacer()
                            Text("Original")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Format Settings")
                    } footer: {
                        Text("The output format will always match the original file format (e.g. MP3 stays MP3). WAV and FLAC files will be automatically converted to MP3 format because they are lossless and cannot be compressed by target bitrate.")
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
                            Text("Original format keeps the same format as input file (MP3 stays MP3, M4A stays M4A, etc.). Bitrate, sample rate, and channel settings will still apply to compress the file.")
                        } else if settings.audioFormat == .flac {
                            Text("FLAC is lossless compression, bitrate setting is not applicable. Original quality will be preserved.")
                        } else if settings.audioFormat == .wav {
                            Text("WAV is uncompressed PCM audio, bitrate setting is not applicable.")
                        } else {
                            Text("Smart quality protection: If the original audio quality is lower than target settings, the original quality will be preserved to avoid unnecessary file size increase. For example, if original is 64 kbps and you set 128 kbps, it will remain at 64 kbps.")
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
                                    Text("Bitrate: Won't increase from low to high (e.g., 64 kbps → 128 kbps)")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("Sample Rate: Won't increase from low to high (e.g., 44.1 kHz → 48 kHz)")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("Channels: Won't convert mono to stereo")
                                }
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                    Text("WAV/FLAC: Automatically converted to MP3 (Lossless formats)")
                                        .foregroundStyle(.orange)
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
                .navigationTitle("Audio Compression Settings")
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
