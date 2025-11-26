//
//  VideoMainView.swift
//  medra
//
//  Created by admin on 2025/11/23.
//

import SwiftUI

struct VideoMainView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: CompressionViewVideo()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                .font(.system(size: 30))
                                .foregroundStyle(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Compress Videos")
                                    .font(.headline)
                                Text("MP4, MOV, M4V")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: VideoFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 30))
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Convert Format")
                                    .font(.headline)
                                Text("MP4, MOV, M4V")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
//                    NavigationLink(destination: ResolutionView()) {
//                        HStack(spacing: 16) {
//                            Image(systemName: "aspectratio")
//                                .font(.system(size: 30))
//                                .foregroundStyle(.purple)
//                                .frame(width: 40)
//                            
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text("Adjust Resolution")
//                                    .font(.headline)
//                                Text("Resize videos")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                        .padding(.vertical, 8)
//                    }
                } header: {
                    Text("Basic Tools")
                }
                
                Section {
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
                                Text("Extract Audio")
                                    .font(.headline)
                                Text("Extract audio from video")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Advanced Tools")
                }
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    VideoMainView()
}
