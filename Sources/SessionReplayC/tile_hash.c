#include "tile_hash.h"

typedef uint64_t unaligned_u64 __attribute__((aligned(1)));
typedef uint32_t unaligned_u32 __attribute__((aligned(1)));

static int nearest_divisor(int value, int preferred, int rangeLo, int rangeHi) {
    if (value <= 0) return preferred;
    if (preferred >= rangeLo && preferred <= rangeHi &&
        preferred > 0 && value % preferred == 0)
        return preferred;

    int maxDist = rangeHi - preferred;
    if (preferred - rangeLo > maxDist) maxDist = preferred - rangeLo;
    if (maxDist <= 0) return preferred;

    for (int offset = 1; offset <= maxDist; offset++) {
        int pos = preferred + offset;
        if (pos >= rangeLo && pos <= rangeHi && pos > 0 && value % pos == 0)
            return pos;
        int neg = preferred - offset;
        if (neg >= rangeLo && neg <= rangeHi && neg > 0 && value % neg == 0)
            return neg;
    }
    return preferred;
}

TileHashResult tile_hash(const void *data,
                         int startX, int startY,
                         int endX,   int endY,
                         int bytesPerRow) {
    uint64_t h0 = UINT64_C(0x517cc1b727220a95);
    uint64_t h1 = UINT64_C(0x6c62272e07bb0142);
    uint64_t h2 = UINT64_C(0x9e3779b97f4a7c15);
    uint64_t h3 = UINT64_C(0xbf58476d1ce4e5b9);

    const int byteWidth = (endX - startX) * 4;
    const int quads     = byteWidth >> 5;
    const int remBytes  = byteWidth & 31;
    const int rem8      = remBytes >> 3;
    const int tail      = remBytes & 4;

    const unsigned char *rowPtr = (const unsigned char *)data
                                + (size_t)startY * bytesPerRow
                                + (size_t)startX * 4;

    for (int y = startY; y < endY; y++) {
        const unsigned char *p = rowPtr;

        for (int i = 0; i < quads; i++) {
            h0 ^= *(const unaligned_u64 *)(p);
            h1 ^= *(const unaligned_u64 *)(p + 8);
            h2 ^= *(const unaligned_u64 *)(p + 16);
            h3 ^= *(const unaligned_u64 *)(p + 24);
            h0 = (h0 << 29) | (h0 >> 35);
            h1 = (h1 << 47) | (h1 >> 17);
            h2 = (h2 << 13) | (h2 >> 51);
            h3 = (h3 << 37) | (h3 >> 27);
            p += 32;
        }

        if (rem8 >= 1) { h0 ^= *(const unaligned_u64 *)(p);      h0 = (h0 << 29) | (h0 >> 35); }
        if (rem8 >= 2) { h1 ^= *(const unaligned_u64 *)(p + 8);  h1 = (h1 << 47) | (h1 >> 17); }
        if (rem8 >= 3) { h2 ^= *(const unaligned_u64 *)(p + 16); h2 = (h2 << 13) | (h2 >> 51); }

        if (tail) {
            h3 ^= (uint64_t)(*(const unaligned_u32 *)(p + rem8 * 8));
            h3 = (h3 << 37) | (h3 >> 27);
        }

        rowPtr += bytesPerRow;
    }

    h0 ^= h2; h1 ^= h3;
    h0 ^= h0 >> 33; h0 *= UINT64_C(0xff51afd7ed558ccd); h0 ^= h0 >> 33;
    h1 ^= h1 >> 29; h1 *= UINT64_C(0xc4ceb9fe1a85ec53); h1 ^= h1 >> 29;

    TileHashResult result;
    result.hashLo = (int64_t)h0;
    result.hashHi = (int64_t)h1;
    return result;
}

TileLayout tile_compute_layout(int imageWidth, int imageHeight) {
    TileLayout layout;
    layout.tileWidth  = nearest_divisor(imageWidth,  64, 60, 79);
    layout.tileHeight = nearest_divisor(imageHeight, 22, 22, 44);
    layout.columns = (imageWidth  + layout.tileWidth  - 1) / layout.tileWidth;
    layout.rows    = (imageHeight + layout.tileHeight - 1) / layout.tileHeight;
    return layout;
}

void tile_compute_all(const void *data,
                      int imageWidth, int imageHeight,
                      int bytesPerRow,
                      TileLayout layout,
                      TileHashResult *out) {
    int idx = 0;
    for (int row = 0; row < layout.rows; row++) {
        int startY = row * layout.tileHeight;
        int endY   = startY + layout.tileHeight;
        if (endY > imageHeight) endY = imageHeight;

        for (int col = 0; col < layout.columns; col++) {
            int startX = col * layout.tileWidth;
            int endX   = startX + layout.tileWidth;
            if (endX > imageWidth) endX = imageWidth;

            out[idx] = tile_hash(data, startX, startY, endX, endY, bytesPerRow);
            idx++;
        }
    }
}
