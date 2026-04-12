#include <metal_stdlib>
using namespace metal;

struct SHA3BatchParams {
    uint count;
    uint inputStride;
    uint inputLength;
    uint outputStride;
};

struct MerkleParentParams {
    uint pairCount;
};

struct MerkleFuseParams {
    uint nodeCount;
};

struct MerkleSubtree32Params {
    uint leafCount;
    uint inputStride;
    uint subtreeLeafCount;
};

struct TranscriptPackParams {
    uint byteCount;
};

struct TranscriptPackWordsParams {
    uint wordCount;
};

struct TranscriptAbsorbParams {
    uint byteCount;
};

struct TranscriptSqueezeParams {
    uint challengeCount;
    uint fieldModulus;
};

struct SumcheckParams {
    uint laneCount;
    uint challenge;
    uint fieldModulus;
};

constant ulong AZK_FC_LEAF_BYTES [[function_constant(1)]];
constant ulong AZK_FC_PARENT_BYTES [[function_constant(2)]];
constant ulong AZK_FC_TREE_ARITY [[function_constant(3)]];
constant ulong AZK_FC_TREELET_DEPTH [[function_constant(4)]];
constant ulong AZK_FC_FIXED_WIDTH_CASE [[function_constant(5)]];
constant ulong AZK_FC_BARRIER_CADENCE [[function_constant(7)]];
constant ulong AZK_FC_DOMAIN_SUFFIX [[function_constant(8)]];

constant ulong KECCAKF_ROUND_CONSTANTS[24] = {
    0x0000000000000001UL,
    0x0000000000008082UL,
    0x800000000000808AUL,
    0x8000000080008000UL,
    0x000000000000808BUL,
    0x0000000080000001UL,
    0x8000000080008081UL,
    0x8000000000008009UL,
    0x000000000000008AUL,
    0x0000000000000088UL,
    0x0000000080008009UL,
    0x000000008000000AUL,
    0x000000008000808BUL,
    0x800000000000008BUL,
    0x8000000000008089UL,
    0x8000000000008003UL,
    0x8000000000008002UL,
    0x8000000000000080UL,
    0x000000000000800AUL,
    0x800000008000000AUL,
    0x8000000080008081UL,
    0x8000000000008080UL,
    0x0000000080000001UL,
    0x8000000080008008UL,
};

constant uint KECCAKF_RHO[24] = {
    1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
    27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
};

constant uint KECCAKF_PI[24] = {
    10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
    15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
};

inline ulong rotl64(ulong value, uint amount) {
    return (value << amount) | (value >> (64 - amount));
}

inline ulong load_le64_partial(const device uchar *src, uint count) {
    ulong value = 0;
    for (uint i = 0; i < count; ++i) {
        value |= ulong(src[i]) << (8 * i);
    }
    return value;
}

inline ulong load_le64(const device uchar *src) {
    ulong value = 0;
    value |= ulong(src[0]);
    value |= ulong(src[1]) << 8;
    value |= ulong(src[2]) << 16;
    value |= ulong(src[3]) << 24;
    value |= ulong(src[4]) << 32;
    value |= ulong(src[5]) << 40;
    value |= ulong(src[6]) << 48;
    value |= ulong(src[7]) << 56;
    return value;
}

inline ulong load_le64_tg(const threadgroup uchar *src) {
    ulong value = 0;
    value |= ulong(src[0]);
    value |= ulong(src[1]) << 8;
    value |= ulong(src[2]) << 16;
    value |= ulong(src[3]) << 24;
    value |= ulong(src[4]) << 32;
    value |= ulong(src[5]) << 40;
    value |= ulong(src[6]) << 48;
    value |= ulong(src[7]) << 56;
    return value;
}

inline void store_le64(ulong value, device uchar *dst) {
    dst[0] = uchar((value >> 0) & 0xffUL);
    dst[1] = uchar((value >> 8) & 0xffUL);
    dst[2] = uchar((value >> 16) & 0xffUL);
    dst[3] = uchar((value >> 24) & 0xffUL);
    dst[4] = uchar((value >> 32) & 0xffUL);
    dst[5] = uchar((value >> 40) & 0xffUL);
    dst[6] = uchar((value >> 48) & 0xffUL);
    dst[7] = uchar((value >> 56) & 0xffUL);
}

inline void store_le64_tg(ulong value, threadgroup uchar *dst) {
    dst[0] = uchar((value >> 0) & 0xffUL);
    dst[1] = uchar((value >> 8) & 0xffUL);
    dst[2] = uchar((value >> 16) & 0xffUL);
    dst[3] = uchar((value >> 24) & 0xffUL);
    dst[4] = uchar((value >> 32) & 0xffUL);
    dst[5] = uchar((value >> 40) & 0xffUL);
    dst[6] = uchar((value >> 48) & 0xffUL);
    dst[7] = uchar((value >> 56) & 0xffUL);
}

inline void clear_state(thread ulong s[25]) {
    for (uint i = 0; i < 25; ++i) {
        s[i] = 0;
    }
}

inline void store_sha3_256_digest(thread ulong s[25], device uchar *dst) {
    store_le64(s[0], dst + 0);
    store_le64(s[1], dst + 8);
    store_le64(s[2], dst + 16);
    store_le64(s[3], dst + 24);
}

inline void store_sha3_256_digest_tg(thread ulong s[25], threadgroup uchar *dst) {
    store_le64_tg(s[0], dst + 0);
    store_le64_tg(s[1], dst + 8);
    store_le64_tg(s[2], dst + 16);
    store_le64_tg(s[3], dst + 24);
}

inline void keccak_f1600(thread ulong s[25]) {
    thread ulong c[5];

    for (uint round = 0; round < 24; ++round) {
        for (uint x = 0; x < 5; ++x) {
            c[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];
        }

        for (uint x = 0; x < 5; ++x) {
            const ulong d = c[(x + 4) % 5] ^ rotl64(c[(x + 1) % 5], 1);
            s[x] ^= d;
            s[x + 5] ^= d;
            s[x + 10] ^= d;
            s[x + 15] ^= d;
            s[x + 20] ^= d;
        }

        ulong current = s[1];
        for (uint i = 0; i < 24; ++i) {
            const uint j = KECCAKF_PI[i];
            const ulong next = s[j];
            s[j] = rotl64(current, KECCAKF_RHO[i]);
            current = next;
        }

        for (uint row = 0; row < 25; row += 5) {
            const ulong a0 = s[row + 0];
            const ulong a1 = s[row + 1];
            const ulong a2 = s[row + 2];
            const ulong a3 = s[row + 3];
            const ulong a4 = s[row + 4];
            s[row + 0] = a0 ^ ((~a1) & a2);
            s[row + 1] = a1 ^ ((~a2) & a3);
            s[row + 2] = a2 ^ ((~a3) & a4);
            s[row + 3] = a3 ^ ((~a4) & a0);
            s[row + 4] = a4 ^ ((~a0) & a1);
        }

        s[0] ^= KECCAKF_ROUND_CONSTANTS[round];
    }
}

inline void absorb_fixed_32(const device uchar *msg, thread ulong state[25], uchar domainSuffix) {
    clear_state(state);
    state[0] = load_le64(msg + 0);
    state[1] = load_le64(msg + 8);
    state[2] = load_le64(msg + 16);
    state[3] = load_le64(msg + 24);
    state[4] ^= ulong(domainSuffix);
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);
}

inline void absorb_fixed_64(const device uchar *msg, thread ulong state[25], uchar domainSuffix) {
    clear_state(state);
    state[0] = load_le64(msg + 0);
    state[1] = load_le64(msg + 8);
    state[2] = load_le64(msg + 16);
    state[3] = load_le64(msg + 24);
    state[4] = load_le64(msg + 32);
    state[5] = load_le64(msg + 40);
    state[6] = load_le64(msg + 48);
    state[7] = load_le64(msg + 56);
    state[8] ^= ulong(domainSuffix);
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);
}

inline void absorb_fixed_128(const device uchar *msg, thread ulong state[25], uchar domainSuffix) {
    clear_state(state);
    state[0] = load_le64(msg + 0);
    state[1] = load_le64(msg + 8);
    state[2] = load_le64(msg + 16);
    state[3] = load_le64(msg + 24);
    state[4] = load_le64(msg + 32);
    state[5] = load_le64(msg + 40);
    state[6] = load_le64(msg + 48);
    state[7] = load_le64(msg + 56);
    state[8] = load_le64(msg + 64);
    state[9] = load_le64(msg + 72);
    state[10] = load_le64(msg + 80);
    state[11] = load_le64(msg + 88);
    state[12] = load_le64(msg + 96);
    state[13] = load_le64(msg + 104);
    state[14] = load_le64(msg + 112);
    state[15] = load_le64(msg + 120);
    state[16] ^= ulong(domainSuffix);
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);
}

inline void absorb_fixed_136(const device uchar *msg, thread ulong state[25], uchar domainSuffix) {
    clear_state(state);
    state[0] = load_le64(msg + 0);
    state[1] = load_le64(msg + 8);
    state[2] = load_le64(msg + 16);
    state[3] = load_le64(msg + 24);
    state[4] = load_le64(msg + 32);
    state[5] = load_le64(msg + 40);
    state[6] = load_le64(msg + 48);
    state[7] = load_le64(msg + 56);
    state[8] = load_le64(msg + 64);
    state[9] = load_le64(msg + 72);
    state[10] = load_le64(msg + 80);
    state[11] = load_le64(msg + 88);
    state[12] = load_le64(msg + 96);
    state[13] = load_le64(msg + 104);
    state[14] = load_le64(msg + 112);
    state[15] = load_le64(msg + 120);
    state[16] = load_le64(msg + 128);
    keccak_f1600(state);

    state[0] ^= ulong(domainSuffix);
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);
}

inline void absorb_fixed_64_tg(const threadgroup uchar *msg, thread ulong state[25], uchar domainSuffix) {
    clear_state(state);
    state[0] = load_le64_tg(msg + 0);
    state[1] = load_le64_tg(msg + 8);
    state[2] = load_le64_tg(msg + 16);
    state[3] = load_le64_tg(msg + 24);
    state[4] = load_le64_tg(msg + 32);
    state[5] = load_le64_tg(msg + 40);
    state[6] = load_le64_tg(msg + 48);
    state[7] = load_le64_tg(msg + 56);
    state[8] ^= ulong(domainSuffix);
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);
}

inline void sha3_256_absorb_fixed_32(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_32(msg, state, uchar(0x06u));
}

inline void sha3_256_absorb_fixed_64(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_64(msg, state, uchar(0x06u));
}

inline void sha3_256_absorb_fixed_128(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_128(msg, state, uchar(0x06u));
}

inline void sha3_256_absorb_fixed_136(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_136(msg, state, uchar(0x06u));
}

inline void sha3_256_absorb_fixed_64_tg(const threadgroup uchar *msg, thread ulong state[25]) {
    absorb_fixed_64_tg(msg, state, uchar(0x06u));
}

inline void keccak_256_absorb_fixed_32(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_32(msg, state, uchar(0x01u));
}

inline void keccak_256_absorb_fixed_64(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_64(msg, state, uchar(0x01u));
}

inline void keccak_256_absorb_fixed_128(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_128(msg, state, uchar(0x01u));
}

inline void keccak_256_absorb_fixed_136(const device uchar *msg, thread ulong state[25]) {
    absorb_fixed_136(msg, state, uchar(0x01u));
}

kernel void sha3_256_oneblock(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    clear_state(state);

    const device uchar *msg = inputs + gid * params.inputStride;
    for (uint lane = 0; lane < 17; ++lane) {
        const uint base = lane * 8;
        if (base < params.inputLength) {
            const uint count = min(8u, params.inputLength - base);
            state[lane] ^= load_le64_partial(msg + base, count);
        }
    }

    const uint padLane = params.inputLength >> 3;
    const uint padShift = (params.inputLength & 7u) * 8u;
    state[padLane] ^= ulong(0x06u) << padShift;
    state[16] ^= ulong(0x80u) << 56;

    keccak_f1600(state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_oneblock_specialized(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    thread ulong state[25];
    clear_state(state);

    const device uchar *msg = inputs + gid * params.inputStride;
    if (inputLength == 136u) {
        for (uint lane = 0; lane < 17; ++lane) {
            state[lane] = load_le64(msg + lane * 8);
        }
        keccak_f1600(state);
        state[0] ^= ulong(AZK_FC_DOMAIN_SUFFIX);
        state[16] ^= ulong(0x80u) << 56;
        keccak_f1600(state);

        device uchar *dst = outputs + gid * params.outputStride;
        store_sha3_256_digest(state, dst);
        return;
    }

    for (uint lane = 0; lane < 17; ++lane) {
        const uint base = lane * 8;
        if (base < inputLength) {
            const uint count = min(8u, inputLength - base);
            state[lane] ^= load_le64_partial(msg + base, count);
        }
    }

    const uint padLane = inputLength >> 3;
    const uint padShift = (inputLength & 7u) * 8u;
    state[padLane] ^= ulong(AZK_FC_DOMAIN_SUFFIX) << padShift;
    state[16] ^= ulong(0x80u) << 56;

    keccak_f1600(state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_32bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    sha3_256_absorb_fixed_32(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_64bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    sha3_256_absorb_fixed_64(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_128bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    sha3_256_absorb_fixed_128(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_136bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    sha3_256_absorb_fixed_136(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_oneblock(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    clear_state(state);

    const device uchar *msg = inputs + gid * params.inputStride;
    for (uint lane = 0; lane < 17; ++lane) {
        const uint base = lane * 8;
        if (base < params.inputLength) {
            const uint count = min(8u, params.inputLength - base);
            state[lane] ^= load_le64_partial(msg + base, count);
        }
    }

    const uint padLane = params.inputLength >> 3;
    const uint padShift = (params.inputLength & 7u) * 8u;
    state[padLane] ^= ulong(0x01u) << padShift;
    state[16] ^= ulong(0x80u) << 56;

    keccak_f1600(state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_oneblock_specialized(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    thread ulong state[25];
    clear_state(state);

    const device uchar *msg = inputs + gid * params.inputStride;
    if (inputLength == 136u) {
        for (uint lane = 0; lane < 17; ++lane) {
            state[lane] = load_le64(msg + lane * 8);
        }
        keccak_f1600(state);
        state[0] ^= ulong(AZK_FC_DOMAIN_SUFFIX);
        state[16] ^= ulong(0x80u) << 56;
        keccak_f1600(state);

        device uchar *dst = outputs + gid * params.outputStride;
        store_sha3_256_digest(state, dst);
        return;
    }

    for (uint lane = 0; lane < 17; ++lane) {
        const uint base = lane * 8;
        if (base < inputLength) {
            const uint count = min(8u, inputLength - base);
            state[lane] ^= load_le64_partial(msg + base, count);
        }
    }

    const uint padLane = inputLength >> 3;
    const uint padShift = (inputLength & 7u) * 8u;
    state[padLane] ^= ulong(AZK_FC_DOMAIN_SUFFIX) << padShift;
    state[16] ^= ulong(0x80u) << 56;

    keccak_f1600(state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_32bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    keccak_256_absorb_fixed_32(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_64bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    keccak_256_absorb_fixed_64(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_128bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    keccak_256_absorb_fixed_128(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void keccak_256_136bytes(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    thread ulong state[25];
    const device uchar *msg = inputs + gid * params.inputStride;
    keccak_256_absorb_fixed_136(msg, state);

    device uchar *dst = outputs + gid * params.outputStride;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_merkle_parents_32x32(
    const device uchar *children [[buffer(0)]],
    device uchar *parents [[buffer(1)]],
    constant MerkleParentParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pairCount) {
        return;
    }

    thread ulong state[25];
    const device uchar *src = children + gid * 64;
    sha3_256_absorb_fixed_64(src, state);

    device uchar *dst = parents + gid * 32;
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_merkle_parents_specialized(
    const device uchar *children [[buffer(0)]],
    device uchar *parents [[buffer(1)]],
    constant MerkleParentParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pairCount) {
        return;
    }

    thread ulong state[25];
    const device uchar *src = children + gid * uint(AZK_FC_PARENT_BYTES * AZK_FC_TREE_ARITY);
    sha3_256_absorb_fixed_64(src, state);

    device uchar *dst = parents + gid * uint(AZK_FC_PARENT_BYTES);
    store_sha3_256_digest(state, dst);
}

kernel void sha3_256_merkle_fuse_upper_32(
    const device uchar *children [[buffer(0)]],
    device uchar *root [[buffer(1)]],
    constant MerkleFuseParams &params [[buffer(2)]],
    threadgroup uchar *scratch [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]])
{
    const uint nodeCount = params.nodeCount;

    for (uint node = tid; node < nodeCount; node += threadsPerThreadgroup) {
        const device uchar *src = children + node * 32;
        threadgroup uchar *dst = scratch + node * 32;
        store_le64_tg(load_le64(src + 0), dst + 0);
        store_le64_tg(load_le64(src + 8), dst + 8);
        store_le64_tg(load_le64(src + 16), dst + 16);
        store_le64_tg(load_le64(src + 24), dst + 24);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint levelCount = nodeCount;
    while (levelCount > 1) {
        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        levelCount = parentCount;
    }

    if (tid == 0) {
        store_le64(load_le64_tg(scratch + 0), root + 0);
        store_le64(load_le64_tg(scratch + 8), root + 8);
        store_le64(load_le64_tg(scratch + 16), root + 16);
        store_le64(load_le64_tg(scratch + 24), root + 24);
    }
}

kernel void sha3_256_merkle_subtrees_32byte_leaves(
    const device uchar *leaves [[buffer(0)]],
    device uchar *subtreeRoots [[buffer(1)]],
    constant MerkleSubtree32Params &params [[buffer(2)]],
    threadgroup uchar *scratch [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]])
{
    const uint baseLeaf = tgid * params.subtreeLeafCount;

    if (tid < params.subtreeLeafCount) {
        const uint leaf = baseLeaf + tid;
        if (leaf < params.leafCount) {
            thread ulong state[25];
            const device uchar *src = leaves + leaf * params.inputStride;
            sha3_256_absorb_fixed_32(src, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint levelCount = params.subtreeLeafCount;
    while (levelCount > 1) {
        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        levelCount = parentCount;
    }

    if (tid == 0) {
        device uchar *root = subtreeRoots + tgid * 32;
        store_le64(load_le64_tg(scratch + 0), root + 0);
        store_le64(load_le64_tg(scratch + 8), root + 8);
        store_le64(load_le64_tg(scratch + 16), root + 16);
        store_le64(load_le64_tg(scratch + 24), root + 24);
    }
}

kernel void sha3_256_merkle_treelet_32byte_leaves(
    const device uchar *leaves [[buffer(0)]],
    device uchar *subtreeRoots [[buffer(1)]],
    constant MerkleSubtree32Params &params [[buffer(2)]],
    threadgroup uchar *scratch [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]])
{
    const uint baseLeaf = tgid * params.subtreeLeafCount;

    if (tid < params.subtreeLeafCount) {
        const uint leaf = baseLeaf + tid;
        if (leaf < params.leafCount) {
            thread ulong state[25];
            const device uchar *src = leaves + leaf * params.inputStride;
            sha3_256_absorb_fixed_32(src, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint levelCount = params.subtreeLeafCount;
    while (levelCount > 1) {
        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        levelCount = parentCount;
    }

    if (tid == 0) {
        device uchar *root = subtreeRoots + tgid * 32;
        store_le64(load_le64_tg(scratch + 0), root + 0);
        store_le64(load_le64_tg(scratch + 8), root + 8);
        store_le64(load_le64_tg(scratch + 16), root + 16);
        store_le64(load_le64_tg(scratch + 24), root + 24);
    }
}

kernel void transcript_pack_bytes(
    const device uchar *input [[buffer(0)]],
    device uchar *packed [[buffer(1)]],
    constant TranscriptPackParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.byteCount) {
        return;
    }
    packed[gid] = input[gid];
}

kernel void transcript_pack_u32_words(
    const device uint *input [[buffer(0)]],
    device uchar *packed [[buffer(1)]],
    constant TranscriptPackWordsParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.wordCount) {
        return;
    }

    const uint word = input[gid];
    const uint base = gid * 4;
    packed[base + 0] = uchar(word & 0xffu);
    packed[base + 1] = uchar((word >> 8) & 0xffu);
    packed[base + 2] = uchar((word >> 16) & 0xffu);
    packed[base + 3] = uchar((word >> 24) & 0xffu);
}

kernel void transcript_absorb_keccak(
    const device uchar *packed [[buffer(0)]],
    device ulong *transcriptState [[buffer(1)]],
    constant TranscriptAbsorbParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid != 0) {
        return;
    }

    thread ulong state[25];
    for (uint i = 0; i < 25; ++i) {
        state[i] = transcriptState[i];
    }

    uint offset = 0;
    while (offset + 136u <= params.byteCount) {
        for (uint lane = 0; lane < 17; ++lane) {
            state[lane] ^= load_le64(packed + offset + lane * 8);
        }
        keccak_f1600(state);
        offset += 136u;
    }

    const uint tailLength = params.byteCount - offset;
    for (uint lane = 0; lane < 17; ++lane) {
        const uint base = lane * 8;
        if (base < tailLength) {
            const uint count = min(8u, tailLength - base);
            state[lane] ^= load_le64_partial(packed + offset + base, count);
        }
    }

    const uint padLane = tailLength >> 3;
    const uint padShift = (tailLength & 7u) * 8u;
    state[padLane] ^= ulong(AZK_FC_DOMAIN_SUFFIX) << padShift;
    state[16] ^= ulong(0x80u) << 56;
    keccak_f1600(state);

    for (uint i = 0; i < 25; ++i) {
        transcriptState[i] = state[i];
    }
}

kernel void transcript_squeeze_challenges(
    const device ulong *transcriptState [[buffer(0)]],
    device uint *challenges [[buffer(1)]],
    constant TranscriptSqueezeParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.challengeCount) {
        return;
    }

    const uint lane = gid & 15u;
    const ulong word = transcriptState[lane >> 1];
    const uint candidate = uint((word >> ((lane & 1u) * 32u)) & 0xffffffffUL);
    const uint modulus = max(params.fieldModulus, 1u);
    challenges[gid] = candidate % modulus;
}

inline uint add_mod(uint a, uint b, uint modulus) {
    const ulong sum = ulong(a) + ulong(b);
    return uint(sum % ulong(modulus));
}

inline uint mul_add_mod(uint a, uint b, uint challenge, uint modulus) {
    const ulong value = ulong(a) + ulong(b) * ulong(challenge);
    return uint(value % ulong(modulus));
}

kernel void sumcheck_scalar(
    const device uint *current [[buffer(0)]],
    device uint *next [[buffer(1)]],
    device uint *coefficients [[buffer(2)]],
    constant SumcheckParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    const uint pairCount = params.laneCount >> 1;
    if (gid >= pairCount) {
        return;
    }

    const uint modulus = max(params.fieldModulus, 1u);
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = add_mod(a, b, modulus);
    next[gid] = mul_add_mod(a, b, params.challenge, modulus);
}

kernel void sumcheck_simdgroup(
    const device uint *current [[buffer(0)]],
    device uint *next [[buffer(1)]],
    device uint *coefficients [[buffer(2)]],
    constant SumcheckParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    const uint pairCount = params.laneCount >> 1;
    if (gid >= pairCount) {
        return;
    }

    const uint modulus = max(params.fieldModulus, 1u);
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = add_mod(a, b, modulus);
    next[gid] = mul_add_mod(a, b, params.challenge, modulus);
}

kernel void sumcheck_fused(
    const device uint *current [[buffer(0)]],
    device uint *next [[buffer(1)]],
    device uint *coefficients [[buffer(2)]],
    constant SumcheckParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    const uint pairCount = params.laneCount >> 1;
    if (gid >= pairCount) {
        return;
    }

    const uint modulus = max(params.fieldModulus, 1u);
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = add_mod(a, b, modulus);
    next[gid] = mul_add_mod(a, b, params.challenge, modulus);
}

kernel void sumcheck_round_eval_u32(
    const device uint *current [[buffer(0)]],
    device uint *coefficients [[buffer(1)]],
    constant SumcheckParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    const uint pairCount = params.laneCount >> 1;
    if (gid >= pairCount) {
        return;
    }

    const uint modulus = max(params.fieldModulus, 1u);
    const uint a = current[gid * 2] % modulus;
    const uint b = current[gid * 2 + 1] % modulus;
    coefficients[gid * 2] = a;
    coefficients[gid * 2 + 1] = b;
}

kernel void sumcheck_fold_halve_u32(
    const device uint *current [[buffer(0)]],
    const device uint *challenge [[buffer(1)]],
    device uint *next [[buffer(2)]],
    constant SumcheckParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    const uint pairCount = params.laneCount >> 1;
    if (gid >= pairCount) {
        return;
    }

    const uint modulus = max(params.fieldModulus, 1u);
    const uint a = current[gid * 2] % modulus;
    const uint b = current[gid * 2 + 1] % modulus;
    next[gid] = mul_add_mod(a, b, challenge[0] % modulus, modulus);
}
