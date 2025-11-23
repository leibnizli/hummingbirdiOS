//
//  FormatMainView.swift
//  hummingbird
//
//  Format Conversion Main View
//

import SwiftUI

struct TransformMainView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Video to Animation")) {
                    NavigationLink(destination: VideoToAnimationView(format: .webp)) {
                        HStack(spacing: 16) {
                            Image(systemName: "film.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Video to Animation")
                                    .font(.headline)
                                Text("Convert video to animated WebP, AVIF, or GIF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    NavigationLink(destination: VideoToAudioView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.teal)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Video to Audio")
                                    .font(.headline)
                                Text("Extract audio from video")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                Section(header: Text("Format Conversion")) {
                    NavigationLink(destination: ImageFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Image Format Conversion")
                                    .font(.headline)
                                Text("JPEG, PNG, GIF, WebP, HEIC, AVIF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: VideoFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "video.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Video Format Conversion")
                                    .font(.headline)
                                Text("MP4, MOV, M4V")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: AudioFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "music.note")
                                .font(.system(size: 40))
                                .foregroundStyle(.purple)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio Format Conversion")
                                    .font(.headline)
                                Text("MP3, M4A, FLAC, WAV")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                Section(header: Text("Media resolution")) {
                    NavigationLink(destination: ResolutionView()) {
                        Text("Adjust media resolution")
                    }
                }
            }
            .navigationTitle("Media Transform")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    TransformMainView()
}
