#include "tile_hash.h"

typedef uint64_t unaligned_u64 __attribute__((aligned(1)));
typedef uint32_t unaligned_u32 __attribute__((aligned(1)));

TileHashResult tile_hash(const void *data,
                         int startX, int startY,
                         int endX,   int endY,
                         int bytesPerRow) {
    uint64_t hashLo = UINT64_C(5163949831757626579);
    uint64_t hashHi = UINT64_C(4657936482115123397);

    const int pixelCount = endX - startX;
    const int pairCount  = pixelCount >> 1;
    const int trailing   = pixelCount & 1;

    const unsigned char *rowPtr = (const unsigned char *)data
                                + (size_t)startY * bytesPerRow
                                + (size_t)startX * 4;

    for (int y = startY; y < endY; y++) {
        const unsigned char *p = rowPtr;

        for (int i = 0; i < pairCount; i++) {
            uint64_t v = *(const unaligned_u64 *)p;
            hashLo = (hashLo ^ v) * UINT64_C(1238197591667094937);
            hashHi = (hashHi ^ v) * UINT64_C(1700294137212722571);
            p += 8;
        }

        if (trailing) {
            uint64_t v = (uint64_t)(*(const unaligned_u32 *)p);
            hashLo = (hashLo ^ v) * UINT64_C(1238197591667094937);
            hashHi = (hashHi ^ v) * UINT64_C(1700294137212722571);
        }

        rowPtr += bytesPerRow;
    }

    TileHashResult result;
    result.hashLo = (int64_t)hashLo;
    result.hashHi = (int64_t)hashHi;
    return result;
}
