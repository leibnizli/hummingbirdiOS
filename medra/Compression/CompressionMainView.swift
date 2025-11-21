//
//  FormatMainView.swift
//  hummingbird
//
//  Format Conversion Main View
//

import SwiftUI

struct CompressionMainView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CompressionViewImage()) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Image")
                                .font(.headline)
                            Text("HEIC, JPEG, PNG, WebP, AVIF")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("WebP animation supported • AVIF animation preserved")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: CompressionViewVideo()) {
                    HStack(spacing: 16) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video")
                                .font(.headline)
                            Text("MP4, MOV, M4V")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: CompressionViewAudio()) {
                    HStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundStyle(.purple)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Audio")
                                .font(.headline)
                            Text("MP3, AAC, M4A, OPUS, FLAC, WAV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Media Compression")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FormatMainView()
}
