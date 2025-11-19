//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "MozJPEGEncoder.h"
#include "zopfli/zopfli.h"
#include "zopflipng/zopflipng_lib.h" // 如果用 PNG 压缩
#import "PNGQuantBridge.h"

#if __has_include("../Pods/libavif/include/avif/avif.h")
#include "../Pods/libavif/include/avif/avif.h"
#endif
