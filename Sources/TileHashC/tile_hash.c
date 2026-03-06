#include "tile_hash.h"
#include <string.h>

TileHashResult tile_hash(const void *data,
                         int startX, int startY,
                         int endX,   int endY,
                         int bytesPerRow) {
    uint64_t hashLo = UINT64_C(5163949831757626579);
    uint64_t hashHi = UINT64_C(4657936482115123397);
    const uint64_t primeLo = UINT64_C(1238197591667094937);
    const uint64_t primeHi = UINT64_C(1700294137212722571);

    const int pixelCount = endX - startX;
    const int pairCount  = pixelCount >> 1;
    const int trailing   = pixelCount & 1;

    const unsigned char *base = (const unsigned char *)data;

    for (int y = startY; y < endY; y++) {
        const unsigned char *p = base + (size_t)y * bytesPerRow + (size_t)startX * 4;

        for (int i = 0; i < pairCount; i++) {
            uint64_t v;
            memcpy(&v, p, 8);
            hashLo = (hashLo ^ v) * primeLo;
            hashHi = (hashHi ^ v) * primeHi;
            p += 8;
        }

        if (trailing) {
            uint32_t v32;
            memcpy(&v32, p, 4);
            uint64_t v = (uint64_t)v32;
            hashLo = (hashLo ^ v) * primeLo;
            hashHi = (hashHi ^ v) * primeHi;
        }
    }

    TileHashResult result;
    result.hashLo = (int64_t)hashLo;
    result.hashHi = (int64_t)hashHi;
    return result;
}
