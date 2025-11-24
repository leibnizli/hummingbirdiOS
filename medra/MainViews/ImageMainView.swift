//
//  ImageMainView.swift
//  medra
//
//  Created by admin on 2025/11/23.
//

import SwiftUI

struct ImageMainView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: CompressionViewImage()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                                .font(.system(size: 30))
                                .foregroundStyle(.green)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Compress Images")
                                    .font(.headline)
                                Text("HEIC, JPEG, PNG, GIF, WebP, AVIF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("WebP, AVIF, GIF animation supported")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: ImageFormatConversionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 30))
                                .foregroundStyle(.blue)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Convert Format")
                                    .font(.headline)
                                Text("JPEG, PNG, GIF, WebP, HEIC, AVIF")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    NavigationLink(destination: ResolutionView()) {
                        HStack(spacing: 16) {
                            Image(systemName: "aspectratio")
                                .font(.system(size: 30))
                                .foregroundStyle(.purple)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Adjust Resolution")
                                    .font(.headline)
                                Text("Resize images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Image Tools")
                }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ImageMainView()
}
