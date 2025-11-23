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
            TransformMainView()
                .tabItem {
                    Label("Transform", systemImage: "wand.and.stars")
                }
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}

#Preview {
    ContentView()
}
