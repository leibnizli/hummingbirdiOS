//
//  FormatMainView.swift
//  hummingbird
//
//  Format Conversion Main View
//

import SwiftUI

struct FormatMainView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: ImageFormatConversionView()) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Image Format Conversion")
                                .font(.headline)
                            Text("JPEG, PNG, WebP, HEIC, AVIF")
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
                            Text("MP3, AAC, M4A, OPUS, FLAC, WAV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
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
                }
            }
            .navigationTitle("Format Conversion")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FormatMainView()
}
