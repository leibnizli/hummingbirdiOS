//
//  hummingbirdApp.swift
//  hummingbird
//
//  Created by admin on 2025/11/4.
//

import SwiftUI
import SwiftData
import SDWebImage
import SDWebImageWebPCoder

@main
struct hummingbirdApp: App {
    
    init() {
        // 注册 WebP coder，使 SDAnimatedImage 能够解码 WebP 动画
        SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
        print("✅ [App] WebP coder 已注册")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
