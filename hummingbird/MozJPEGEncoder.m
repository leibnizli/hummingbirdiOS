#import "MozJPEGEncoder.h"
#import <mozjpeg/jconfig.h>
#import <mozjpeg/jpeglib.h>

@implementation MozJPEGEncoder

+ (nullable NSData *)encodeImage:(UIImage *)image quality:(CGFloat)quality {
    // 确保质量在有效范围内
    quality = MAX(0.01, MIN(1.0, quality));
    int jpegQuality = (int)(quality * 100);
    
    NSLog(@"[MozJPEG] 开始压缩 - 质量: %.2f (%d%%)", quality, jpegQuality);
    
    // 获取 CGImage
    CGImageRef cgImage = image.CGImage;
    if (!cgImage) {
        NSLog(@"[MozJPEG] ❌ 错误: CGImage 为 nil");
        return nil;
    }
    
    // 获取图片信息
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    NSLog(@"[MozJPEG] 图片尺寸: %zux%zu", width, height);
    
    // 创建位图上下文来获取原始像素数据
    // 注意：kCGImageAlphaNoneSkipLast 使用 4 字节每像素（RGBA，但 alpha 被忽略）
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 计算每行字节数，需要对齐到 16 字节边界
    // 使用 4 字节每像素（因为 kCGImageAlphaNoneSkipLast）
    size_t bytesPerPixel = 4;
    size_t bytesPerRow = ((width * bytesPerPixel + 15) / 16) * 16; // 对齐到 16 字节
    
    NSLog(@"[MozJPEG] 内存分配 - 宽度: %zu, 每像素: %zu 字节, 每行: %zu 字节", width, bytesPerPixel, bytesPerRow);
    
    unsigned char *rawData = (unsigned char *)malloc(height * bytesPerRow);
    if (!rawData) {
        NSLog(@"[MozJPEG] ❌ 错误: 内存分配失败 (需要 %zu bytes)", height * bytesPerRow);
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    
    CGContextRef context = CGBitmapContextCreate(rawData,
                                                  width,
                                                  height,
                                                  8,
                                                  bytesPerRow,
                                                  colorSpace,
                                                  kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        NSLog(@"[MozJPEG] ❌ 错误: 无法创建位图上下文");
        free(rawData);
        return nil;
    }
    
    // 绘制图片到上下文
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
    
    // 使用 mozjpeg 的标准 libjpeg API
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    
    NSLog(@"[MozJPEG] JPEG 压缩结构已创建");
    
    // 设置输出到内存
    unsigned char *jpegBuf = NULL;
    unsigned long jpegSize = 0;
    jpeg_mem_dest(&cinfo, &jpegBuf, &jpegSize);
    
    NSLog(@"[MozJPEG] 内存目标已设置");
    
    // 设置图片参数
    cinfo.image_width = (JDIMENSION)width;
    cinfo.image_height = (JDIMENSION)height;
    cinfo.input_components = 3; // RGB
    cinfo.in_color_space = JCS_RGB;
    
    jpeg_set_defaults(&cinfo);
    
    // 设置压缩质量和优化选项
    jpeg_set_quality(&cinfo, jpegQuality, TRUE);
    
    // 启用 mozjpeg 的优化特性
    cinfo.optimize_coding = TRUE; // 霍夫曼编码优化
    
    // 使用渐进式 JPEG（更好的压缩率）
    jpeg_simple_progression(&cinfo);
    
    // 开始压缩
    jpeg_start_compress(&cinfo, TRUE);
    
    // 逐行写入数据
    // 注意：rawData 是 RGBA 格式（4 字节每像素），需要转换为 RGB（3 字节每像素）
    JSAMPROW row_pointer[1];
    unsigned char *rgbRow = (unsigned char *)malloc(width * 3); // RGB 行缓冲区
    if (!rgbRow) {
        NSLog(@"[MozJPEG] ❌ 错误: 无法分配 RGB 行缓冲区");
        jpeg_abort_compress(&cinfo);
        jpeg_destroy_compress(&cinfo);
        free(rawData);
        return nil;
    }
    
    while (cinfo.next_scanline < cinfo.image_height) {
        // 从 RGBA 转换为 RGB
        unsigned char *rgbaRow = &rawData[cinfo.next_scanline * bytesPerRow];
        for (size_t i = 0; i < width; i++) {
            rgbRow[i * 3 + 0] = rgbaRow[i * 4 + 0]; // R
            rgbRow[i * 3 + 1] = rgbaRow[i * 4 + 1]; // G
            rgbRow[i * 3 + 2] = rgbaRow[i * 4 + 2]; // B
            // 跳过 alpha (i * 4 + 3)
        }
        row_pointer[0] = rgbRow;
        jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    
    free(rgbRow);
    
    // 完成压缩
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    
    free(rawData);
    
    // 创建 NSData
    NSData *jpegData = nil;
    if (jpegBuf && jpegSize > 0) {
        jpegData = [NSData dataWithBytes:jpegBuf length:jpegSize];
        NSLog(@"[MozJPEG] ✅ 压缩成功 - 输出大小: %lu bytes", jpegSize);
        free(jpegBuf); // 释放 mozjpeg 分配的内存
    } else {
        NSLog(@"[MozJPEG] ❌ 错误: 压缩后数据为空 (jpegBuf: %p, jpegSize: %lu)", jpegBuf, jpegSize);
    }
    
    return jpegData;
}

@end
