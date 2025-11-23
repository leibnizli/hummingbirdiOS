//
//  AudioMainView.swift
//  medra
//
//  Created by admin on 2025/11/23.
//

import SwiftUI

struct AudioMainView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: CompressionViewAudio()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                .font(.system(size: 30))
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Compress Audio")
                                    .font(.headline)
                                Text("MP3, M4A, AAC, FLAC, WAV, OGG")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: AudioFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 30))
                                .foregroundStyle(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Convert Format")
                                    .font(.headline)
                                Text("MP3, M4A, FLAC, WAV")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Audio Tools")
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AudioMainView()
}
