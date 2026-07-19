inline uint32_t clz(uint32_t x) {
    uint32_t r = 0;
    if (!(x & 0xFFFF0000)) { r += 16; x <<= 16; }
    if (!(x & 0xFF000000)) { r += 8;  x <<= 8;  }
    if (!(x & 0xF0000000)) { r += 4;  x <<= 4;  }
    if (!(x & 0xC0000000)) { r += 2;  x <<= 2;  }
    if (!(x & 0x80000000)) { r += 1; }
    return r;
}

// `x` is a uint256 bit number represented with 8 uint32 limbs.
// This implementation is optimized for SP1 proving via rv32im.
// For regular compute, it performs similarly to `ADD`.
inline uint32_t clz(uint32_t x[8]) {
    if (x[7] != 0) return clz(x[7]);
    if (x[6] != 0) return 32 + clz(x[6]);
    if (x[5] != 0) return 64 + clz(x[5]);
    if (x[4] != 0) return 96 + clz(x[4]);
    if (x[3] != 0) return 128 + clz(x[3]);
    if (x[2] != 0) return 160 + clz(x[2]);
    if (x[1] != 0) return 192 + clz(x[1]);
    if (x[0] != 0) return 224 + clz(x[0]);
    return 256;
}
