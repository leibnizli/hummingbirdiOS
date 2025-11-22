//
//  ContentView.swift
//  hummingbird
//
//  Created by admin on 2025/11/4.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CompressionMainView()
                .tabItem {
                    Label("Compress", systemImage: "bolt.fill")
                }
//            ResolutionView()
//                .tabItem {
//                    Label("Resolution", systemImage: "arrow.up.left.and.arrow.down.right")
//                }
            FormatMainView()
                .tabItem {
                    Label("Format", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}

#Preview {
    ContentView()
}
