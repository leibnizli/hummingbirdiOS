#ifndef PNGQuantBridge_h
#define PNGQuantBridge_h

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct liq_attr liq_attr;
typedef struct liq_image liq_image;
typedef struct liq_result liq_result;
typedef struct liq_palette liq_palette;

typedef struct liq_color {
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
} liq_color;

struct liq_palette {
    unsigned int count;
    liq_color entries[256];
};

typedef enum liq_error {
    LIQ_OK = 0,
    LIQ_QUALITY_TOO_LOW = 99,
    LIQ_VALUE_OUT_OF_RANGE = 100,
    LIQ_OUT_OF_MEMORY,
    LIQ_ABORTED,
    LIQ_BITMAP_NOT_AVAILABLE,
    LIQ_BUFFER_TOO_SMALL,
    LIQ_INVALID_POINTER,
    LIQ_UNSUPPORTED,
} liq_error;

enum liq_ownership {
    LIQ_OWN_ROWS = 4,
    LIQ_OWN_PIXELS = 8,
    LIQ_COPY_PIXELS = 16,
};

liq_attr *liq_attr_create(void);
liq_attr *liq_attr_create_with_allocator(void *removed, void *unsupported);
liq_attr *liq_attr_copy(const liq_attr *orig);
void liq_attr_destroy(liq_attr *attr);

liq_error liq_set_quality(liq_attr *attr, int minimum, int maximum);
liq_error liq_set_speed(liq_attr *attr, int speed);
liq_error liq_attr_set_progress_callback(liq_attr *attr, int (*callback)(float progress_percent, void *user_info), void *user_info);

liq_image *liq_image_create_rgba(const liq_attr *attr, const void *bitmap, int width, int height, double gamma);
liq_error liq_image_set_memory_ownership(liq_image *image, int ownership_flags);
void liq_image_destroy(liq_image *image);

liq_error liq_image_quantize(liq_image *image, liq_attr *options, liq_result **result_output);
liq_error liq_set_dithering_level(liq_result *result, float dither_level);
const liq_palette *liq_get_palette(liq_result *result);
liq_error liq_write_remapped_image(liq_result *result, liq_image *image, void *buffer, size_t buffer_size);
int liq_get_quantization_quality(const liq_result *result);
void liq_result_destroy(liq_result *result);

#ifdef __cplusplus
}
#endif

#endif /* PNGQuantBridge_h */
