//
//  ResolutionItemRow.swift
//  hummingbird
//
//  Media item row view for resolution modification feature
//

import SwiftUI
import Photos

struct ResolutionItemRow: View {
    @ObservedObject var item: MediaItem
    @State private var showingToast = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Preview image
                ZStack {
                    Color.gray.opacity(0.2)
                    
                    if let thumbnail = item.thumbnailImage {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Information area
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: item.isVideo ? "video.circle.fill" : "photo.circle.fill")
                            .foregroundStyle(item.isVideo ? .blue : .green)
                        
                        // File extension
                        if !item.fileExtension.isEmpty {
                            Text(item.fileExtension.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            // 显示动画标志
                            if item.isAnimatedWebP || item.isAnimatedAVIF {
                                Image(systemName: "film.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        // Status badge
                        statusBadge
                    }
                    
                    // 动画转换规则说明（独立一行）
                    if item.isAnimatedWebP || item.isAnimatedAVIF {
                        let isCompleted = item.status == .completed
                        
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text(isCompleted ? "Only first frame was kept" : "Only first frame will be kept")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                    
                    // Resolution information
                    if item.status == .completed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resolution: \(item.formatResolution(item.originalResolution)) → \(item.formatResolution(item.compressedResolution))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("Size: \(item.formatBytes(item.originalSize)) → \(item.formatBytes(item.compressedSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            // Show video duration and codec (video only)
                            if item.isVideo {
                                Text("Duration: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Show codec change
                                if let originalCodec = item.videoCodec, let compressedCodec = item.compressedVideoCodec {
                                    if originalCodec != compressedCodec {
                                        Text("Codec: \(originalCodec) → \(compressedCodec)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Codec: \(originalCodec)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                } else if let codec = item.videoCodec {
                                    Text("Codec: \(codec)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            if let resolution = item.originalResolution {
                                Text("Resolution: \(item.formatResolution(resolution))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Size: \(item.formatBytes(item.originalSize))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // Show video duration and codec (video only)
                            if item.isVideo {
                                Text("Duration: \(item.formatDuration(item.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Show codec
                                if let codec = item.videoCodec {
                                    Text("Codec: \(codec)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Progress bar
                    if item.status == .processing {
                        ProgressView(value: Double(item.progress))
                            .tint(.blue)
                    }
                    
                    // Error message
                    if let error = item.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }
            
            // Save buttons
            if item.status == .completed {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: { saveToPhotos(item) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.arrow.down")
                                    .font(.caption)
                                Text("Photos")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { saveToICloud(item) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.caption)
                                Text("iCloud")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { shareFile(item) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption)
                                Text("Share")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .toast(isShowing: $showingToast, message: "Saved successfully")
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .loading:
            HStack(spacing: 3) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .pending:
            HStack(spacing: 3) {
                Image(systemName: "clock")
                Text("Pending")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case .compressing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Compressing")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .processing:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Processing")
            }
            .font(.caption)
            .foregroundStyle(.blue)
            .lineLimit(1)
        case .completed:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                Text("Completed")
            }
            .font(.caption)
            .foregroundStyle(.green)
            .lineLimit(1)
        case .failed:
            HStack(spacing: 3) {
                Image(systemName: "xmark.circle.fill")
                Text("Failed")
            }
            .font(.caption)
            .foregroundStyle(.red)
            .lineLimit(1)
        }
    }
    
    private func saveToPhotos(_ item: MediaItem) {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                print("Photo library permission denied")
                return
            }
            
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    if item.isVideo, let url = item.compressedVideoURL {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    } else if let data = item.compressedData {
                        // Use PHAssetCreationRequest.forAsset() to preserve original data format
                        // This preserves animated WebP and other special formats
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: data, options: nil)
                        print("✅ [ResolutionItemRow] Saving image, size: \(data.count) bytes, format: \(item.outputImageFormat?.rawValue ?? "unknown")")
                    }
                }
                await MainActor.run {
                    withAnimation {
                        showingToast = true
                    }
                }
            } catch {
                print("Save failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToICloud(_ item: MediaItem) {
        print("🔵 [iCloud] 使用文档选择器保存")
        
        // 准备临时文件
        var fileURL: URL?
        
        if item.isVideo, let url = item.compressedVideoURL {
            fileURL = url
        } else if let data = item.compressedData {
            let fileExtension: String
            switch item.outputImageFormat {
            case .heic:
                fileExtension = "heic"
            case .png:
                fileExtension = "png"
            case .webp:
                fileExtension = "webp"
            case .avif:
                fileExtension = "avif"
            case .jpeg:
                fileExtension = "jpg"
            default:
                fileExtension = "jpg"
            }
            
            let fileName = "resized_\(Date().timeIntervalSince1970).\(fileExtension)"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                fileURL = tempURL
            } catch {
                print("❌ [iCloud] 创建临时文件失败")
                return
            }
        }
        
        guard let sourceURL = fileURL,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // 创建文档选择器 - 导出模式
        let documentPicker = UIDocumentPickerViewController(forExporting: [sourceURL], asCopy: true)
        
        // 创建 coordinator 来处理回调
        let coordinator = DocumentPickerCoordinator { success in
            Task { @MainActor in
                if success {
                    withAnimation {
                        self.showingToast = true
                    }
                    print("✅ [iCloud] 文件保存成功")
                } else {
                    print("⚠️ [iCloud] 用户取消保存")
                }
            }
        }
        documentPicker.delegate = coordinator
        
        // 保持 coordinator 的引用
        objc_setAssociatedObject(documentPicker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
        
        // iPad 需要设置 popover
        if let popover = documentPicker.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        print("📤 [iCloud] 显示文档选择器")
        rootViewController.present(documentPicker, animated: true)
    }
    
    // Document Picker Coordinator
    private class DocumentPickerCoordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Bool) -> Void
        
        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(true)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(false)
        }
    }
    
    private func shareFile(_ item: MediaItem) {
        print("📤 [Share] 打开分享界面")
        
        var itemsToShare: [Any] = []
        
        if item.isVideo, let url = item.compressedVideoURL {
            itemsToShare.append(url)
        } else if let data = item.compressedData {
            let fileExtension: String
            switch item.outputImageFormat {
            case .heic:
                fileExtension = "heic"
            case .png:
                fileExtension = "png"
            case .webp:
                fileExtension = "webp"
            case .avif:
                fileExtension = "avif"
            case .jpeg:
                fileExtension = "jpg"
            default:
                fileExtension = "jpg"
            }
            
            let fileName = "resized_\(Date().timeIntervalSince1970).\(fileExtension)"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                itemsToShare.append(tempURL)
            } catch {
                return
            }
        }
        
        guard !itemsToShare.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        // 设置完成回调
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            Task { @MainActor in
                if completed {
                    withAnimation {
                        self.showingToast = true
                    }
                    print("✅ [Share] 分享成功")
                } else if let error = error {
                    print("❌ [Share] 分享失败: \(error)")
                } else {
                    print("⚠️ [Share] 用户取消分享")
                }
            }
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityVC, animated: true)
    }
}
