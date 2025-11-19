//
//  ImageFormatConversionView.swift
//  hummingbird
//
//  Image Format Conversion View
//

import SwiftUI
import PhotosUI
import AVFoundation
import SDWebImageWebPCoder
import ImageIO

struct ImageFormatConversionView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isConverting = false
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @StateObject private var settings = FormatSettings()
    
    private var hasLoadingItems: Bool {
        mediaItems.contains { $0.status == .loading }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部按钮
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Menu {
                        Button(action: { showingPhotoPicker = true }) {
                            Label("Select from Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        
                        Button(action: { showingFilePicker = true }) {
                            Label("Select from Files", systemImage: "folder.fill")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Files")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isConverting || hasLoadingItems)
                    
                    Button(action: startConversion) {
                        HStack(spacing: 6) {
                            if isConverting || hasLoadingItems {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            Text(isConverting ? "Processing" : hasLoadingItems ? "Loading" : "Start")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(mediaItems.isEmpty || isConverting || hasLoadingItems ? .gray : .green)
                    .disabled(mediaItems.isEmpty || isConverting || hasLoadingItems)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .systemGroupedBackground))
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            
            // 设置区域
            VStack(spacing: 0) {
                HStack {
                    Text("Target Format")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: $settings.targetImageFormat) {
                        Text("JPEG").tag(ImageFormat.jpeg)
                        Text("PNG").tag(ImageFormat.png)
                        Text("HEIC").tag(ImageFormat.heic)
                        Text("WebP").tag(ImageFormat.webp)
                        Text("AVIF").tag(ImageFormat.avif)
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 16)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preserve EXIF Data")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        Text("Keep photo metadata like camera settings and location")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.preserveExif)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(height: 0.5)
            }
            .background(Color(uiColor: .systemBackground))
            
            // 文件列表
            if mediaItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select images to convert")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(mediaItems) { item in
                        FormatItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.visible)
                    }
                    .onDelete { indexSet in
                        guard !isConverting && !hasLoadingItems else { return }
                        withAnimation {
                            mediaItems.remove(atOffsets: indexSet)
                        }
                    }
                    .deleteDisabled(isConverting || hasLoadingItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Image Format")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItems, maxSelectionCount: 20, matching: .images)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                Task {
                    await loadFilesFromURLs(urls)
                }
            } catch {
                print("File selection failed: \(error.localizedDescription)")
            }
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
    
    private func startConversion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isConverting = true
        }
        
        Task {
            await MainActor.run {
                for item in mediaItems {
                    item.status = .pending
                    item.progress = 0
                    item.compressedData = nil
                    item.compressedSize = 0
                    item.errorMessage = nil
                }
            }
            
            for item in mediaItems {
                await convertItem(item)
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isConverting = false
                }
            }
        }
    }
    
    private func convertItem(_ item: MediaItem) async {
        await MainActor.run {
            item.status = .processing
            item.progress = 0
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await convertImage(item)
    }
    
    private func convertImage(_ item: MediaItem) async {
        print("[convertImage] 开始图片转换")
        
        guard let originalData = item.originalData else {
            print(" [convertImage] 无法加载原始图片数据")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法加载原始图片"
            }
            return
        }
        print("[convertImage] 原始数据大小: \(originalData.count) bytes")
        
        // 加载图片
        guard let image = UIImage(data: originalData) else {
            print(" [convertImage] 无法解码图片")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法解码图片"
            }
            return
        }
        print("[convertImage] 图片解码成功，尺寸: \(image.size)")
        
        // 创建 CGImageSource 用于读取元数据
        guard let imageSource = CGImageSourceCreateWithData(originalData as CFData, nil) else {
            print(" [convertImage] 无法创建 CGImageSource")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "无法创建图片源"
            }
            return
        }
        
        await MainActor.run {
            item.progress = 0.3
        }
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 秒
        
        // 转换为目标格式
        let convertedData: Data?
        let outputFormat = settings.targetImageFormat
        print("[convertImage] 目标格式: \(outputFormat.rawValue)")
        
        switch outputFormat {
        case .jpeg:
            print("[convertImage] 转换为 JPEG")
            
            await MainActor.run {
                item.progress = 0.4
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.jpeg.identifier as CFString, 1, nil) else {
                print(" [convertImage] 无法创建 JPEG destination")
                convertedData = nil
                break
            }
            
            await MainActor.run {
                item.progress = 0.5
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 如果需要保留 EXIF 信息，从原始图片源复制元数据
            if settings.preserveExif {
                print("[convertImage] preserveExif = true，尝试保留元数据")
                
                // 获取原始元数据
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary? {
                    print("[convertImage] ✅ 成功读取元数据")
                    print("[convertImage] 元数据键: \(properties.allKeys)")
                    
                    // 获取原始 CGImage
                    if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        // 创建可变的元数据字典
                        let mutableProperties = NSMutableDictionary(dictionary: properties)
                        
                        // 添加压缩质量选项
                        mutableProperties[kCGImageDestinationLossyCompressionQuality] = 1.0
                        
                        print("[convertImage] 添加图片和元数据到 destination")
                        CGImageDestinationAddImage(destination, cgImage, mutableProperties as CFDictionary)
                    } else {
                        print("⚠️ [convertImage] 无法从 imageSource 创建 CGImage")
                        if let cgImage = image.cgImage {
                            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
                        }
                    }
                } else {
                    print("⚠️ [convertImage] 未找到元数据，使用默认方式")
                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: 1.0
                    ]
                    if let cgImage = image.cgImage {
                        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    }
                }
            } else {
                print("[convertImage] preserveExif = false，不保留元数据")
                // 不保留 EXIF，使用修正方向后的图片
                let fixedImage = image.fixOrientation()
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 1.0
                ]
                if let cgImage = fixedImage.cgImage {
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                }
            }
            
            await MainActor.run {
                item.progress = 0.7
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            if CGImageDestinationFinalize(destination) {
                convertedData = destinationData as Data
                print("[convertImage] ✅ JPEG 转换成功，大小: \(destinationData.length) bytes")
            } else {
                print("❌ [convertImage] JPEG finalize 失败")
                convertedData = nil
            }
            
        case .png:
            print("[convertImage] 转换为 PNG")
            
            await MainActor.run {
                item.progress = 0.4
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            let destinationData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(destinationData, UTType.png.identifier as CFString, 1, nil) else {
                print(" [convertImage] 无法创建 PNG destination")
                convertedData = nil
                break
            }
            
            await MainActor.run {
                item.progress = 0.5
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 如果需要保留 EXIF 信息，从原始图片源复制元数据
            if settings.preserveExif {
                print("[convertImage] preserveExif = true，尝试保留元数据")
                
                // 获取原始元数据
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary? {
                    print("[convertImage] ✅ 成功读取元数据")
                    
                    // 获取原始 CGImage
                    if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        print("[convertImage] 添加图片和元数据到 destination")
                        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
                    } else {
                        print("⚠️ [convertImage] 无法从 imageSource 创建 CGImage")
                        if let cgImage = image.cgImage {
                            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
                        }
                    }
                } else {
                    print("⚠️ [convertImage] 未找到元数据，使用默认方式")
                    if let cgImage = image.cgImage {
                        CGImageDestinationAddImage(destination, cgImage, nil)
                    }
                }
            } else {
                print("[convertImage] preserveExif = false，不保留元数据")
                // 不保留 EXIF，使用修正方向后的图片
                let fixedImage = image.fixOrientation()
                if let cgImage = fixedImage.cgImage {
                    CGImageDestinationAddImage(destination, cgImage, nil)
                }
            }
            
            await MainActor.run {
                item.progress = 0.7
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            if CGImageDestinationFinalize(destination) {
                convertedData = destinationData as Data
                print("[convertImage] ✅ PNG 转换成功，大小: \(destinationData.length) bytes")
            } else {
                print("❌ [convertImage] PNG finalize 失败")
                convertedData = nil
            }
            
        case .webp:
            print("[convertImage] 转换为 WebP")
            
            await MainActor.run {
                item.progress = 0.4
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            let webpCoder = SDImageWebPCoder.shared
            
            // WebP 格式对 EXIF 支持有限，但我们尝试保留
            let imageToEncode: UIImage
            if settings.preserveExif {
                // 保留 EXIF 时使用原始图片（保持原始方向）
                imageToEncode = image
                print("[convertImage] WebP 使用原始图片（注意：WebP 对 EXIF 支持有限）")
            } else {
                // 不保留 EXIF 时修正方向
                imageToEncode = image.fixOrientation()
            }
            
            await MainActor.run {
                item.progress = 0.5
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 使用 0.85 的压缩质量，在质量和体积之间取得平衡
            let options: [SDImageCoderOption: Any] = [
                .encodeCompressionQuality: 0.85
            ]
            convertedData = webpCoder.encodedData(with: imageToEncode, format: .webP, options: options)
            
            await MainActor.run {
                item.progress = 0.7
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            if let data = convertedData {
                print("[convertImage] WebP 转换成功，大小: \(data.count) bytes")
            } else {
                print(" [convertImage] WebP 转换失败")
            }
            
        case .avif:
            print("[convertImage] 转换为 AVIF")
            
            await MainActor.run {
                item.progress = 0.4
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // AVIF 不支持 EXIF，使用修正方向后的图片
            let imageToEncode = image.fixOrientation()
            
            await MainActor.run {
                item.progress = 0.5
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            // 使用 AVIFCompressor 进行编码
            if let result = await AVIFCompressor.compress(
                image: imageToEncode,
                quality: 0.85,
                speedPreset: .balanced,
                backend: .systemImageIO,
                progressHandler: { progress in
                    Task { @MainActor in
                        item.progress = 0.5 + progress * 0.2
                    }
                }
            ) {
                convertedData = result.data
                print("[convertImage] AVIF 转换成功，大小: \(result.data.count) bytes")
            } else {
                print("❌ [convertImage] AVIF 转换失败")
                convertedData = nil
            }
            
            await MainActor.run {
                item.progress = 0.7
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
        case .heic:
            print("[convertImage] 转换为 HEIC")
            
            await MainActor.run {
                item.progress = 0.4
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
            
            if #available(iOS 11.0, *) {
                let destinationData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(destinationData, AVFileType.heic as CFString, 1, nil) else {
                    print(" [convertImage] 无法创建 HEIC destination")
                    convertedData = nil
                    break
                }
                
                await MainActor.run {
                    item.progress = 0.5
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                
                // 如果需要保留 EXIF 信息，从原始图片源复制元数据
                if settings.preserveExif {
                    print("[convertImage] preserveExif = true，尝试保留元数据")
                    
                    // 获取原始元数据
                    if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary? {
                        print("[convertImage] ✅ 成功读取元数据")
                        
                        // 获取原始 CGImage
                        if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                            // 创建可变的元数据字典
                            let mutableProperties = NSMutableDictionary(dictionary: properties)
                            
                            // 添加压缩质量选项
                            mutableProperties[kCGImageDestinationLossyCompressionQuality] = 1.0
                            
                            print("[convertImage] 添加图片和元数据到 destination")
                            CGImageDestinationAddImage(destination, cgImage, mutableProperties as CFDictionary)
                        } else {
                            print("⚠️ [convertImage] 无法从 imageSource 创建 CGImage")
                            if let cgImage = image.cgImage {
                                CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
                            }
                        }
                    } else {
                        print("⚠️ [convertImage] 未找到元数据，使用默认方式")
                        let options: [CFString: Any] = [
                            kCGImageDestinationLossyCompressionQuality: 1.0
                        ]
                        if let cgImage = image.cgImage {
                            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                        }
                    }
                } else {
                    print("[convertImage] preserveExif = false，不保留元数据")
                    // 不保留 EXIF，使用修正方向后的图片
                    let fixedImage = image.fixOrientation()
                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: 1.0
                    ]
                    if let cgImage = fixedImage.cgImage {
                        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    }
                }
                
                await MainActor.run {
                    item.progress = 0.7
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                
                if CGImageDestinationFinalize(destination) {
                    convertedData = destinationData as Data
                    print("[convertImage] ✅ HEIC 转换成功，大小: \(destinationData.length) bytes")
                } else {
                    print("❌ [convertImage] HEIC finalize 失败")
                    convertedData = nil
                }
            } else {
                print(" [convertImage] iOS 版本不支持 HEIC")
                convertedData = nil
            }
        }
        
        await MainActor.run {
            item.progress = 0.8
        }
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
        
        guard let data = convertedData else {
            print(" [convertImage] 转换失败，convertedData 为 nil")
            await MainActor.run {
                item.status = .failed
                item.errorMessage = "格式转换失败"
            }
            return
        }
        
        print("[convertImage] 转换成功，准备保存结果")
        await MainActor.run {
            item.compressedData = data
            item.compressedSize = data.count
            item.outputImageFormat = outputFormat
            item.compressedResolution = image.size
            item.status = .completed
            item.progress = 1.0
            
            print("[格式转换] \(item.originalImageFormat?.rawValue ?? "未知") -> \(outputFormat.rawValue) - 大小: \(data.count) bytes")
        }
        print("[convertImage] 图片转换完成")
    }
    private func loadSelectedItems(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for item in items {
            let mediaItem = MediaItem(pickerItem: item, isVideo: false)
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            await loadImageItem(item, mediaItem)
        }
    }
    
    private func loadFilesFromURLs(_ urls: [URL]) async {
        await MainActor.run {
            mediaItems.removeAll()
        }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let mediaItem = MediaItem(pickerItem: nil, isVideo: false)
            
            await MainActor.run {
                mediaItems.append(mediaItem)
            }
            
            do {
                let data = try Data(contentsOf: url)
                
                await MainActor.run {
                    mediaItem.originalData = data
                    mediaItem.originalSize = data.count
                    mediaItem.fileExtension = url.pathExtension.lowercased()
                    
                    if let type = UTType(filenameExtension: url.pathExtension) {
                        if type.conforms(to: .png) {
                            mediaItem.originalImageFormat = .png
                        } else if type.conforms(to: .heic) {
                            mediaItem.originalImageFormat = .heic
                        } else if type.identifier == "org.webmproject.webp" || type.conforms(to: .webP) {
                            mediaItem.originalImageFormat = .webp
                        } else if let avifType = UTType(filenameExtension: "avif"), type.conforms(to: avifType) {
                            mediaItem.originalImageFormat = .avif
                            mediaItem.fileExtension = "avif"
                        } else {
                            mediaItem.originalImageFormat = .jpeg
                        }
                    } else {
                        switch mediaItem.fileExtension {
                        case "png":
                            mediaItem.originalImageFormat = .png
                        case "heic", "heif":
                            mediaItem.originalImageFormat = .heic
                        case "webp":
                            mediaItem.originalImageFormat = .webp
                        case "avif":
                            mediaItem.originalImageFormat = .avif
                        default:
                            mediaItem.originalImageFormat = .jpeg
                        }
                    }
                    
                    if let image = UIImage(data: data) {
                        mediaItem.thumbnailImage = generateThumbnail(from: image)
                        mediaItem.originalResolution = image.size
                        mediaItem.status = .pending
                    }
                }
            } catch {
                await MainActor.run {
                    mediaItem.status = .failed
                    mediaItem.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadImageItem(_ item: PhotosPickerItem, _ mediaItem: MediaItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run {
                mediaItem.originalData = data
                mediaItem.originalSize = data.count
                
                // 检测原始图片格式（只处理图片）
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
                let avifType = UTType(filenameExtension: "avif")
                let isWebP = item.supportedContentTypes.contains { contentType in
                    contentType.identifier == "org.webmproject.webp" ||
                    contentType.preferredMIMEType == "image/webp"
                }
                let isAVIF = item.supportedContentTypes.contains { contentType in
                    if contentType.identifier == "public.avif" ||
                        contentType.identifier == "public.avci" ||
                        contentType.preferredMIMEType == "image/avif" {
                        return true
                    }
                    if let avifType = avifType {
                        return contentType.conforms(to: avifType)
                    }
                    return false
                }
                
                if isPNG {
                    mediaItem.originalImageFormat = .png
                    mediaItem.fileExtension = "png"
                } else if isHEIC {
                    mediaItem.originalImageFormat = .heic
                    mediaItem.fileExtension = "heic"
                } else if isWebP {
                    mediaItem.originalImageFormat = .webp
                    mediaItem.fileExtension = "webp"
                } else if isAVIF {
                    mediaItem.originalImageFormat = .avif
                    mediaItem.fileExtension = "avif"
                } else {
                    mediaItem.originalImageFormat = .jpeg
                    mediaItem.fileExtension = "jpg"
                }
                
                if let image = UIImage(data: data) {
                    mediaItem.thumbnailImage = generateThumbnail(from: image)
                    mediaItem.originalResolution = image.size
                }
                
                // 加载完成，设置为等待状态
                mediaItem.status = .pending
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
}

#Preview {
    ImageFormatConversionView()
}
