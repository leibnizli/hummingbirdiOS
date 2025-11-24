//
//  AudioMainView.swift
//  medra
//
//  Created by admin on 2025/11/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioMainView: View {
    @State private var showFileImporter = false
    @State private var selectedAudioURL: URL?
    @State private var showTrimView = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: CompressionViewAudio()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                .font(.system(size: 30))
                                .foregroundStyle(.green)
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
                                .foregroundStyle(.blue)
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
                    
                    NavigationLink(destination: AudioToTextView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 30))
                                .foregroundStyle(.purple)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Audio to Text")
                                    .font(.headline)
                                Text("Transcribe audio to text")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: TextToSpeechView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 30))
                                .foregroundStyle(.orange)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Text to Speech")
                                    .font(.headline)
                                Text("Convert text to audio")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
//                    Button(action: {
//                        showFileImporter = true
//                    }) {
//                        HStack(spacing: 16) {
//                            Image(systemName: "scissors")
//                                .font(.system(size: 30))
//                                .foregroundStyle(.orange)
//                                .frame(width: 40)
//                            
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text("Trim Audio")
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//                                Text("Cut and save audio clips")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                        .padding(.vertical, 8)
//                    }
                } header: {
                    Text("Audio Tools")
                }
            }
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        // Access security scoped resource
                        if url.startAccessingSecurityScopedResource() {
                            selectedAudioURL = url
                            showTrimView = true
                        }
                    }
                case .failure(let error):
                    print("File selection error: \(error.localizedDescription)")
                }
            }
            .fullScreenCover(isPresented: $showTrimView, onDismiss: {
                selectedAudioURL?.stopAccessingSecurityScopedResource()
                selectedAudioURL = nil
            }) {
                if let url = selectedAudioURL {
                    AudioTrimView(audioURL: url)
                }
            }
        }
    }
}

#Preview {
    AudioMainView()
}
