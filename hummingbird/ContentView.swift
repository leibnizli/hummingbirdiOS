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
            CompressionView()
                .tabItem {
                    Label("压缩", systemImage: "bolt.fill")
                }
            ResolutionView()
                .tabItem {
                    Label("分辨率", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            FormatView()
                .tabItem {
                    Label("格式", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}

#Preview {
    ContentView()
}
