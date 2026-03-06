#ifndef TILE_HASH_H
#define TILE_HASH_H

#include <stdint.h>

typedef struct {
    int64_t hashLo;
    int64_t hashHi;
} TileHashResult;

/// Computes a fast non-cryptographic hash over the pixel rectangle
/// [startX, endX) x [startY, endY) in a 4-bytes-per-pixel bitmap.
TileHashResult tile_hash(const void *data,
                         int startX, int startY,
                         int endX,   int endY,
                         int bytesPerRow);

#endif
