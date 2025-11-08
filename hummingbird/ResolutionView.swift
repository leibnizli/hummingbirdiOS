//
//  ResolutionView.swift
//  hummingbird
//
//  修改分辨率视图
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos
import SDWebImageWebPCoder

extension NumberFormatter {
    static var noGrouping: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.groupingSeparator = ""
        formatter.usesGroupingSeparator = false
        return formatter
    }
}

struct ResolutionView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isProcessing = false
    @State private var targetResolution: ImageResolution = .wallpaperHD
    @State private var customWidth: Int = 1920
    @State private var customHeight: Int = 1080
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部选择按钮
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos])) {
                        Label("选择文件", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: startBatchResize) {
                        Label("开始调整", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(mediaItems.isEmpty || isProcessing)
                }
                .padding()
                
                // 分辨率设置
                VStack(spacing: 12) {
                    Picker("目标分辨率", selection: $targetResolution) {
                        ForEach(ImageResolution.allCases) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if targetResolution == .custom {
                        HStack(spacing: 12) {
                            HStack {
                                Text("宽度")
                                TextField("1920", value: $customWidth, formatter: NumberFormatter.noGrouping)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("px")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("高度")
                                TextField("1080", value: $customHeight, formatter: NumberFormatter.noGrouping)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                Text("px")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // 文件列表
                if mediaItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("选择图片或视频调整分辨率")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(mediaItems) { item in
                            ResolutionItemRow(item: item)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            withAnimation {
                                mediaItems.remove(atOffsets: indexSet)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("修改分辨率")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { 
                await loadSelectedItems(newItems)
                await MainActor.run {
                    selectedItems = []
                }
            }
        }
    }
    
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        mediaItems.removeAll()
        
        for item in items {
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
            let mediaItem = MediaItem(pickerItem: item, isVideo: isVideo)
            
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    
                    // 检测原始图片格式（从 PhotosPickerItem 的 contentType 检测）
                    if !isVideo {
                        let isPNG = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.png" ||
                            contentType.conforms(to: .png)
                        }
                        let isHEIC = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.heic" || 
                            contentType.identifier == "public.heif" ||
                            contentType.conforms(to: .heic) ||
                            contentType.conforms(to: .heif)
                        }
                        let isWebP = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "org.webmproject.webp" ||
                            contentType.preferredMIMEType == "image/webp"
                        }
                        
                        if isPNG {
                            mediaItem.originalImageFormat = .png
                            mediaItem.fileExtension = "png"
                            print("📋 [分辨率-格式检测] PhotosPickerItem 格式: PNG")
                        } else if isHEIC {
                            mediaItem.originalImageFormat = .heic
                            mediaItem.fileExtension = "heic"
                            print("📋 [分辨率-格式检测] PhotosPickerItem 格式: HEIC")
                        } else if isWebP {
                            mediaItem.originalImageFormat = .webp
                            mediaItem.fileExtension = "webp"
                            print("📋 [分辨率-格式检测] PhotosPickerItem 格式: WebP")
                        } else {
                            mediaItem.originalImageFormat = .jpeg
                            mediaItem.fileExtension = "jpg"
                            print("📋 [分辨率-格式检测] PhotosPickerItem 格式: JPEG")
                        }
                    }
                    
                    if isVideo {
                        // 检测视频格式
                        let isMOV = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "com.apple.quicktime-movie" ||
                            contentType.conforms(to: .quickTimeMovie)
                        }
                        let isMP4 = item.supportedContentTypes.contains { contentType in
                            contentType.identifier == "public.mpeg-4" ||
                            contentType.conforms(to: .mpeg4Movie)
                        }
                        
                        if isMOV {
                            mediaItem.fileExtension = "mov"
                        } else if isMP4 {
                            mediaItem.fileExtension = "mp4"
                        } else {
                            mediaItem.fileExtension = "video"
                        }
                        
                        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                            .appendingPathComponent("source_\(mediaItem.id.uuidString)")
                            .appendingPathExtension("mov")
                        try? data.write(to: tempURL)
                        mediaItem.sourceVideoURL = tempURL
                        
                        let asset = AVURLAsset(url: tempURL)
                        if let videoTrack = asset.tracks(withMediaType: .video).first {
                            let size = videoTrack.naturalSize
                            let transform = videoTrack.preferredTransform
                            let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                            mediaItem.originalResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                        }
                        
                        generateVideoThumbnail(for: mediaItem, url: tempURL)
                    } else {
                        if let image = UIImage(data: data) {
                            mediaItem.thumbnailImage = generateThumbnail(from: image)
                            mediaItem.originalResolution = image.size
                        }
                    }
                }
            }
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
        }
    }
    
    private func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 80, height: 80)) -> UIImage? {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        var targetSize = size
        if aspectRatio > targetAspectRatio {
            targetSize.height = size.width / aspectRatio
        } else {
            targetSize.width = size.height * aspectRatio
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func generateVideoThumbnail(for item: MediaItem, url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        
        Task {
            do {
                let cgImage = try await generator.image(at: .zero).image
                let thumbnail = UIImage(cgImage: cgImage)
                await MainActor.run {
                    item.thumbnailImage = thumbnail
                }
            } catch {
                print("生成视频缩略图失败: \(error)")
            }
        }
    }
    
    private func startBatchResize() {
        isProcessing = true
        
        Task {
            // 重置所有项目状态，以便重新处理
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.compressedResolution = nil
                    item.compressedVideoURL = nil
                    item.usedBitrate = nil
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await resizeItem(item)
            }
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func resizeItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        
        if item.isVideo {
            await resizeVideo(item)
        } else {
            await resizeImage(item)
        }
    }
    
    private func resizeImage(_ item: MediaItem) async {
        guard let originalData = item.originalData else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        
        guard var image = UIImage(data: originalData) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法解码图片"
            }
            return
        }
        
        // 使用原始格式（从 item 中获取）
        let originalFormat = item.originalImageFormat ?? .jpeg
        
        // 修正方向
        image = image.fixOrientation()
        
        // 获取目标尺寸并进行智能裁剪和缩放
        if let (width, height) = getTargetSize() {
            image = resizeAndCropImage(image, targetWidth: width, targetHeight: height)
        }
        
        // 使用系统原生编码（不调用压缩），保持高质量
        let resizedData: Data
        switch originalFormat {
        case .png:
            // PNG 格式 - 无损压缩
            guard let pngData = image.pngData() else {
                await MainActor.run {
                    item.status = .failed
                    item.errorMessage = "无法编码 PNG 图片"
                }
                return
            }
            resizedData = pngData
            print("✅ [分辨率调整] PNG 编码成功 - 大小: \(resizedData.count) bytes")
            
        case .heic:
            // HEIC 格式
            if #available(iOS 11.0, *) {
                let mutableData = NSMutableData()
                if let cgImage = image.cgImage,
                   let destination = CGImageDestinationCreateWithData(mutableData, AVFileType.heic as CFString, 1, nil) {
                    let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        resizedData = mutableData as Data
                        print("✅ [分辨率调整] HEIC 编码成功 - 大小: \(resizedData.count) bytes")
                    } else {
                        await MainActor.run {
                            item.status = .failed
                            item.errorMessage = "HEIC 编码失败"
                        }
                        return
                    }
                } else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法创建 HEIC 编码器"
                    }
                    return
                }
            } else {
                // iOS 11 以下不支持 HEIC，回退到 JPEG
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法编码图片"
                    }
                    return
                }
                resizedData = jpegData
                print("✅ [分辨率调整] JPEG 编码成功（HEIC 不支持） - 大小: \(resizedData.count) bytes")
            }
            
        case .jpeg:
            // JPEG 格式 - 使用系统原生编码
            guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                await MainActor.run {
                    item.status = .failed
                    item.errorMessage = "无法编码图片"
                }
                return
            }
            resizedData = jpegData
            print("✅ [分辨率调整] JPEG 编码成功 - 大小: \(resizedData.count) bytes")
            
        case .webp:
            // WebP 格式 - 使用 SDWebImageWebPCoder
            let webpCoder = SDImageWebPCoder.shared
            if let webpData = webpCoder.encodedData(with: image, format: .webP, options: [.encodeCompressionQuality: 0.9]) {
                resizedData = webpData
                print("✅ [分辨率调整] WebP 编码成功 - 大小: \(resizedData.count) bytes")
            } else {
                // WebP 编码失败，回退到 JPEG
                print("⚠️ [分辨率调整] WebP 编码失败，回退到 JPEG")
                guard let jpegData = image.jpegData(compressionQuality: 0.9) else {
                    await MainActor.run {
                        item.status = .failed
                        item.errorMessage = "无法编码图片"
                    }
                    return
                }
                resizedData = jpegData
                print("✅ [分辨率调整] JPEG 编码成功（WebP 回退） - 大小: \(resizedData.count) bytes")
            }
        }
        
        await MainActor.run {
            item.compressedData = resizedData
            item.compressedSize = resizedData.count
            item.compressedResolution = image.size
            item.outputImageFormat = originalFormat  // 记录输出格式
            item.status = .completed
            item.progress = 1.0
        }
    }
    
    // 智能缩放和裁剪图片到目标尺寸
    private func resizeAndCropImage(_ image: UIImage, targetWidth: Int, targetHeight: Int) -> UIImage {
        let originalSize = image.size
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        // 计算目标宽高比和原始宽高比
        let targetAspectRatio = CGFloat(targetWidth) / CGFloat(targetHeight)
        let originalAspectRatio = originalSize.width / originalSize.height
        
        // 计算缩放比例，使用较大的比例以确保填满目标尺寸
        let scale: CGFloat
        if originalAspectRatio > targetAspectRatio {
            // 原图更宽，以高度为准缩放
            scale = targetSize.height / originalSize.height
        } else {
            // 原图更高或相同，以宽度为准缩放
            scale = targetSize.width / originalSize.width
        }
        
        // 缩放后的尺寸
        let scaledSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // 计算裁剪区域（居中裁剪）
        let cropRect = CGRect(
            x: (scaledSize.width - targetSize.width) / 2,
            y: (scaledSize.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        
        // 创建渲染器
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        
        // 先缩放到合适大小
        let scaledRenderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        let scaledImage = scaledRenderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        // 然后裁剪到目标尺寸
        let cropRenderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return cropRenderer.image { _ in
            scaledImage.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }
    
    private func resizeVideo(_ item: MediaItem) async {
        guard let sourceURL = item.sourceVideoURL else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始视频"
            }
            return
        }
        
        let asset = AVURLAsset(url: sourceURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法创建导出会话"
            }
            return
        }
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("resized_\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // 设置视频分辨率
        if let (width, height) = getTargetSize() {
            let size = CGSize(width: width, height: height)
            exportSession.videoComposition = createVideoComposition(asset: asset, targetSize: size)
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            Task { @MainActor in
                item.progress = exportSession.progress
            }
            if exportSession.status != .exporting { t.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        
        await exportSession.export()
        
        await MainActor.run {
            switch exportSession.status {
            case .completed:
                item.compressedVideoURL = outputURL
                if let data = try? Data(contentsOf: outputURL) {
                    item.compressedSize = data.count
                }
                
                let resultAsset = AVURLAsset(url: outputURL)
                if let videoTrack = resultAsset.tracks(withMediaType: .video).first {
                    let size = videoTrack.naturalSize
                    let transform = videoTrack.preferredTransform
                    let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
                    item.compressedResolution = isPortrait ? CGSize(width: size.height, height: size.width) : size
                }
                
                item.status = .completed
                item.progress = 1.0
            default:
                item.status = .failed
                item.errorMessage = exportSession.error?.localizedDescription ?? "导出失败"
            }
        }
    }
    
    // 创建视频合成，实现智能缩放和裁剪
    private func createVideoComposition(asset: AVAsset, targetSize: CGSize) -> AVMutableVideoComposition {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return AVMutableVideoComposition()
        }
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = targetSize
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        // 获取视频原始尺寸和方向
        let videoSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
        let actualSize = isPortrait ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
        
        // 计算宽高比
        let targetAspectRatio = targetSize.width / targetSize.height
        let videoAspectRatio = actualSize.width / actualSize.height
        
        // 使用较大的缩放比例以填满目标尺寸（会裁剪超出部分）
        let scale: CGFloat
        if videoAspectRatio > targetAspectRatio {
            // 视频更宽，以高度为准
            scale = targetSize.height / actualSize.height
        } else {
            // 视频更高，以宽度为准
            scale = targetSize.width / actualSize.width
        }
        
        // 计算缩放后的尺寸
        let scaledSize = CGSize(width: actualSize.width * scale, height: actualSize.height * scale)
        
        // 计算居中偏移
        let tx = (targetSize.width - scaledSize.width) / 2
        let ty = (targetSize.height - scaledSize.height) / 2
        
        // 构建变换矩阵
        var finalTransform = CGAffineTransform.identity
        
        // 先应用原始的旋转/翻转变换
        finalTransform = finalTransform.concatenating(transform)
        
        // 然后缩放
        finalTransform = finalTransform.scaledBy(x: scale, y: scale)
        
        // 最后平移到居中位置
        if isPortrait {
            // 竖屏视频需要特殊处理偏移
            finalTransform = finalTransform.translatedBy(x: ty, y: tx)
        } else {
            finalTransform = finalTransform.translatedBy(x: tx, y: ty)
        }
        
        transformer.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [transformer]
        composition.instructions = [instruction]
        
        return composition
    }
    
    private func getTargetSize() -> (Int, Int)? {
        if targetResolution == .custom {
            return (customWidth, customHeight)
        } else if let size = targetResolution.size {
            return (size.width, size.height)
        }
        return nil
    }
}

#Preview {
    ResolutionView()
}
