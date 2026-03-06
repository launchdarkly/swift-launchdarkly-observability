import Testing
import SessionReplayC

struct TileHashParityTests {

    private func makePixelBuffer(width: Int, height: Int, seed: UInt8 = 0) -> [UInt8] {
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        var val = seed
        for i in 0..<buffer.count {
            val = val &+ 17 ^ UInt8(truncatingIfNeeded: i)
            buffer[i] = val
        }
        return buffer
    }

    @Test func neonAndScalarProduceSameHash_singleRow() {
        let buffer = makePixelBuffer(width: 64, height: 1)
        let bytesPerRow = Int32(64 * 4)

        let scalar = buffer.withUnsafeBufferPointer {
            tile_hash_w64_scalar($0.baseAddress!, 1, bytesPerRow)
        }
        let neon = buffer.withUnsafeBufferPointer {
            tile_hash_w64_neon($0.baseAddress!, 1, bytesPerRow)
        }

        #expect(scalar.hashLo == neon.hashLo)
        #expect(scalar.hashHi == neon.hashHi)
    }

    @Test func neonAndScalarProduceSameHash_multipleRows() {
        let height = 22
        let buffer = makePixelBuffer(width: 64, height: height)
        let bytesPerRow = Int32(64 * 4)

        let scalar = buffer.withUnsafeBufferPointer {
            tile_hash_w64_scalar($0.baseAddress!, Int32(height), bytesPerRow)
        }
        let neon = buffer.withUnsafeBufferPointer {
            tile_hash_w64_neon($0.baseAddress!, Int32(height), bytesPerRow)
        }

        #expect(scalar.hashLo == neon.hashLo)
        #expect(scalar.hashHi == neon.hashHi)
    }

    @Test func neonAndScalarProduceSameHash_withStride() {
        let width = 128
        let height = 10
        let bytesPerRow = Int32(width * 4)
        let buffer = makePixelBuffer(width: width, height: height, seed: 42)

        let scalar = buffer.withUnsafeBufferPointer {
            tile_hash_w64_scalar($0.baseAddress!, Int32(height), bytesPerRow)
        }
        let neon = buffer.withUnsafeBufferPointer {
            tile_hash_w64_neon($0.baseAddress!, Int32(height), bytesPerRow)
        }

        #expect(scalar.hashLo == neon.hashLo)
        #expect(scalar.hashHi == neon.hashHi)
    }

    @Test func neonAndScalarProduceSameHash_allZeros() {
        let buffer = [UInt8](repeating: 0, count: 64 * 4 * 22)
        let bytesPerRow = Int32(64 * 4)

        let scalar = buffer.withUnsafeBufferPointer {
            tile_hash_w64_scalar($0.baseAddress!, 22, bytesPerRow)
        }
        let neon = buffer.withUnsafeBufferPointer {
            tile_hash_w64_neon($0.baseAddress!, 22, bytesPerRow)
        }

        #expect(scalar.hashLo == neon.hashLo)
        #expect(scalar.hashHi == neon.hashHi)
    }

    @Test func neonAndScalarProduceSameHash_allOnes() {
        let buffer = [UInt8](repeating: 0xFF, count: 64 * 4 * 22)
        let bytesPerRow = Int32(64 * 4)

        let scalar = buffer.withUnsafeBufferPointer {
            tile_hash_w64_scalar($0.baseAddress!, 22, bytesPerRow)
        }
        let neon = buffer.withUnsafeBufferPointer {
            tile_hash_w64_neon($0.baseAddress!, 22, bytesPerRow)
        }

        #expect(scalar.hashLo == neon.hashLo)
        #expect(scalar.hashHi == neon.hashHi)
    }
}
