#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MozJPEGEncoder : NSObject

/// 使用 MozJPEG 压缩图片
/// @param image 要压缩的图片
/// @param quality 压缩质量 (0.0 - 1.0)
/// @return 压缩后的 JPEG 数据，失败返回 nil
+ (nullable NSData *)encodeImage:(UIImage *)image quality:(CGFloat)quality;

@end

NS_ASSUME_NONNULL_END
