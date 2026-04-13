#include <metal_stdlib>
using namespace metal;

struct SHA3BatchParams {
    uint count;
    uint inputStride;
    uint inputLength;
    uint outputStride;
    uint simdgroupsPerThreadgroup;
};

struct KeccakPermutationParams {
    uint count;
    uint inputStride;
    uint outputStride;
    uint simdgroupsPerThreadgroup;
};

struct MerkleParentParams {
    uint pairCount;
};

struct MerkleFuseParams {
    uint nodeCount;
};

struct MerkleExtractParams {
    uint nodeCount;
    uint nodeIndex;
    uint proofOffset;
};

struct MerkleTreeletParams {
    uint leafCount;
    uint inputStride;
    uint subtreeLeafCount;
};

struct MerkleTreeletOpenParams {
    uint leafCount;
    uint inputStride;
    uint subtreeLeafCount;
    uint baseLeaf;
    uint localLeafIndex;
    uint proofOffset;
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

struct M31VectorParams {
    uint count;
    uint operation;
    uint fieldModulus;
};

struct CM31VectorParams {
    uint count;
    uint operation;
    uint fieldModulus;
};

struct QM31VectorParams {
    uint count;
    uint operation;
    uint fieldModulus;
};

struct QM31FRIFoldParams {
    uint pairCount;
    uint fieldModulus;
    uint challengeA;
    uint challengeB;
    uint challengeC;
    uint challengeD;
};

struct M31DotProductParams {
    uint count;
    uint fieldModulus;
    uint elementsPerThreadgroup;
    uint threadsPerThreadgroup;
};

constant ulong AZK_FC_LEAF_BYTES [[function_constant(1)]];
constant ulong AZK_FC_PARENT_BYTES [[function_constant(2)]];
constant ulong AZK_FC_TREE_ARITY [[function_constant(3)]];
constant ulong AZK_FC_TREELET_DEPTH [[function_constant(4)]];
constant ulong AZK_FC_FIXED_WIDTH_CASE [[function_constant(5)]];
constant ulong AZK_FC_BARRIER_CADENCE [[function_constant(7)]];
constant ulong AZK_FC_DOMAIN_SUFFIX [[function_constant(8)]];
constant uint SHA3_256_RATE_U32_WORDS = 34u;
constant uint M31_MODULUS_U32 = 2147483647u;
constant ulong M31_MODULUS_U64 = 2147483647UL;

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

constant uint KECCAKF_SIMD_SOURCE[25] = {
    0, 6, 12, 18, 24,
    3, 9, 10, 16, 22,
    1, 7, 13, 19, 20,
    4, 5, 11, 17, 23,
    2, 8, 14, 15, 21,
};

constant uint KECCAKF_SIMD_RHO[25] = {
    0, 44, 43, 21, 14,
    28, 20, 3, 45, 61,
    1, 6, 25, 8, 18,
    27, 36, 10, 15, 56,
    62, 55, 39, 41, 2,
};

inline ulong rotl64(ulong value, uint amount) {
    return (value << amount) | (value >> (64 - amount));
}

inline ulong rotl64_any(ulong value, uint amount) {
    const uint shift = amount & 63u;
    if (shift == 0u) {
        return value;
    }
    return (value << shift) | (value >> (64u - shift));
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

inline uint2 split_u64(ulong value) {
    return uint2(uint(value & 0xffffffffUL), uint(value >> 32));
}

inline ulong join_u64(uint2 value) {
    return ulong(value.x) | (ulong(value.y) << 32);
}

inline uint2 rotl64_pair(uint2 value, uint amount) {
    const uint shift = amount & 63u;
    if (shift == 0u) {
        return value;
    }
    if (shift < 32u) {
        return uint2(
            (value.x << shift) | (value.y >> (32u - shift)),
            (value.y << shift) | (value.x >> (32u - shift))
        );
    }
    if (shift == 32u) {
        return uint2(value.y, value.x);
    }
    const uint highShift = shift - 32u;
    return uint2(
        (value.y << highShift) | (value.x >> (32u - highShift)),
        (value.x << highShift) | (value.y >> (32u - highShift))
    );
}

inline uint2 shuffle_u64_pair(uint2 value, uint sourceLane) {
    return uint2(
        simd_shuffle(value.x, ushort(sourceLane)),
        simd_shuffle(value.y, ushort(sourceLane))
    );
}

inline uint2 keccak_f1600_simdgroup_pair(uint2 word, uint lane) {
    for (uint round = 0; round < 24; ++round) {
        if (lane < 25u) {
            const uint x = lane % 5u;
            const uint prevX = (x + 4u) % 5u;
            const uint nextX = (x + 1u) % 5u;
            const uint2 cPrev =
                shuffle_u64_pair(word, prevX + 0u) ^
                shuffle_u64_pair(word, prevX + 5u) ^
                shuffle_u64_pair(word, prevX + 10u) ^
                shuffle_u64_pair(word, prevX + 15u) ^
                shuffle_u64_pair(word, prevX + 20u);
            const uint2 cNext =
                shuffle_u64_pair(word, nextX + 0u) ^
                shuffle_u64_pair(word, nextX + 5u) ^
                shuffle_u64_pair(word, nextX + 10u) ^
                shuffle_u64_pair(word, nextX + 15u) ^
                shuffle_u64_pair(word, nextX + 20u);
            word ^= cPrev ^ rotl64_pair(cNext, 1u);
        }

        if (lane < 25u) {
            const uint source = KECCAKF_SIMD_SOURCE[lane];
            const uint rotation = KECCAKF_SIMD_RHO[lane];
            word = rotl64_pair(shuffle_u64_pair(word, source), rotation);
        }

        if (lane < 25u) {
            const uint row = (lane / 5u) * 5u;
            const uint x = lane % 5u;
            const uint2 right1 = shuffle_u64_pair(word, row + ((x + 1u) % 5u));
            const uint2 right2 = shuffle_u64_pair(word, row + ((x + 2u) % 5u));
            word = word ^ ((~right1) & right2);
        }

        if (lane == 0u) {
            word ^= split_u64(KECCAKF_ROUND_CONSTANTS[round]);
        }
    }
    return word;
}

kernel void keccak_f1600_permutation_scalar(
    const device ulong *inputs [[buffer(0)]],
    device ulong *outputs [[buffer(1)]],
    constant KeccakPermutationParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count) {
        return;
    }

    const uint inputBase = gid * (params.inputStride / 8u);
    const uint outputBase = gid * (params.outputStride / 8u);
    thread ulong state[25];
    for (uint lane = 0; lane < 25u; ++lane) {
        state[lane] = inputs[inputBase + lane];
    }

    keccak_f1600(state);

    for (uint lane = 0; lane < 25u; ++lane) {
        outputs[outputBase + lane] = state[lane];
    }
}

kernel void keccak_f1600_permutation_simdgroup(
    const device ulong *inputs [[buffer(0)]],
    device ulong *outputs [[buffer(1)]],
    constant KeccakPermutationParams &params [[buffer(2)]],
    uint lane [[thread_index_in_simdgroup]],
    uint simdgroupIndex [[simdgroup_index_in_threadgroup]],
    uint simdWidth [[threads_per_simdgroup]],
    uint threadgroupIndex [[threadgroup_position_in_grid]])
{
    const uint stateIndex = threadgroupIndex * params.simdgroupsPerThreadgroup + simdgroupIndex;
    if (stateIndex >= params.count || simdWidth < 25u) {
        return;
    }

    uint2 word = uint2(0, 0);
    if (lane < 25u) {
        const uint inputBase = stateIndex * (params.inputStride / 8u);
        word = split_u64(inputs[inputBase + lane]);
    }

    word = keccak_f1600_simdgroup_pair(word, lane);

    if (lane < 25u) {
        const uint outputBase = stateIndex * (params.outputStride / 8u);
        outputs[outputBase + lane] = join_u64(word);
    }
}

inline uint2 load_rate_lane_pair(const device uchar *msg, uint inputLength, uint lane) {
    if (lane >= 17u) {
        return uint2(0, 0);
    }

    const uint base = lane * 8u;
    if (base >= inputLength) {
        return uint2(0, 0);
    }

    const uint count = min(8u, inputLength - base);
    return split_u64(load_le64_partial(msg + base, count));
}

inline uint2 xor_byte_into_lane_pair(uint2 word, uint lane, uint targetLane, uint byteOffset, uchar value) {
    if (lane != targetLane) {
        return word;
    }

    const uint shift = byteOffset * 8u;
    if (shift < 32u) {
        word.x ^= uint(value) << shift;
    } else {
        word.y ^= uint(value) << (shift - 32u);
    }
    return word;
}

inline uint2 absorb_oneblock_simdgroup_pair(
    const device uchar *msg,
    uint inputLength,
    uchar domainSuffix,
    uint lane)
{
    uint2 word = load_rate_lane_pair(msg, inputLength, lane);

    if (inputLength == 136u) {
        word = keccak_f1600_simdgroup_pair(word, lane);
        if (lane == 0u) {
            word.x ^= uint(domainSuffix);
        }
        if (lane == 16u) {
            word.y ^= 0x80000000u;
        }
        return keccak_f1600_simdgroup_pair(word, lane);
    }

    const uint padLane = inputLength >> 3;
    const uint padByte = inputLength & 7u;
    word = xor_byte_into_lane_pair(word, lane, padLane, padByte, domainSuffix);
    if (lane == 16u) {
        word.y ^= 0x80000000u;
    }
    return keccak_f1600_simdgroup_pair(word, lane);
}

inline void store_digest_lane_pair(uint2 word, device uchar *dst, uint lane) {
    if (lane < 4u) {
        store_le64(join_u64(word), dst + lane * 8u);
    }
}

kernel void sha3_256_oneblock_simdgroup_specialized(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint lane [[thread_index_in_simdgroup]],
    uint simdgroupIndex [[simdgroup_index_in_threadgroup]],
    uint simdWidth [[threads_per_simdgroup]],
    uint threadgroupIndex [[threadgroup_position_in_grid]])
{
    const uint gid = threadgroupIndex * params.simdgroupsPerThreadgroup + simdgroupIndex;
    if (gid >= params.count || simdWidth < 25u) {
        return;
    }

    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    const device uchar *msg = inputs + gid * params.inputStride;
    uint2 word = absorb_oneblock_simdgroup_pair(msg, inputLength, uchar(AZK_FC_DOMAIN_SUFFIX), lane);
    device uchar *dst = outputs + gid * params.outputStride;
    store_digest_lane_pair(word, dst, lane);
}

kernel void keccak_256_oneblock_simdgroup_specialized(
    const device uchar *inputs [[buffer(0)]],
    device uchar *outputs [[buffer(1)]],
    constant SHA3BatchParams &params [[buffer(2)]],
    uint lane [[thread_index_in_simdgroup]],
    uint simdgroupIndex [[simdgroup_index_in_threadgroup]],
    uint simdWidth [[threads_per_simdgroup]],
    uint threadgroupIndex [[threadgroup_position_in_grid]])
{
    const uint gid = threadgroupIndex * params.simdgroupsPerThreadgroup + simdgroupIndex;
    if (gid >= params.count || simdWidth < 25u) {
        return;
    }

    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    const device uchar *msg = inputs + gid * params.inputStride;
    uint2 word = absorb_oneblock_simdgroup_pair(msg, inputLength, uchar(AZK_FC_DOMAIN_SUFFIX), lane);
    device uchar *dst = outputs + gid * params.outputStride;
    store_digest_lane_pair(word, dst, lane);
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

inline void sha3_256_absorb_oneblock_leaf_specialized(
    const device uchar *msg,
    uint inputLength,
    thread ulong state[25])
{
    if (inputLength == 32u) {
        sha3_256_absorb_fixed_32(msg, state);
        return;
    }
    if (inputLength == 64u) {
        sha3_256_absorb_fixed_64(msg, state);
        return;
    }
    if (inputLength == 128u) {
        sha3_256_absorb_fixed_128(msg, state);
        return;
    }
    if (inputLength == 136u) {
        sha3_256_absorb_fixed_136(msg, state);
        return;
    }

    clear_state(state);
    for (uint lane = 0; lane < 17u; ++lane) {
        const uint base = lane * 8u;
        if (base < inputLength) {
            const uint count = min(8u, inputLength - base);
            state[lane] ^= load_le64_partial(msg + base, count);
        }
    }

    const uint padLane = inputLength >> 3;
    const uint padShift = (inputLength & 7u) * 8u;
    state[padLane] ^= ulong(0x06u) << padShift;
    state[16] ^= ulong(0x80u) << 56;

    keccak_f1600(state);
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
    const uint scratchStride = nodeCount * 32u;

    for (uint node = tid; node < nodeCount; node += threadsPerThreadgroup) {
        const device uchar *src = children + node * 32;
        threadgroup uchar *dst = scratch + node * 32;
        store_le64_tg(load_le64(src + 0), dst + 0);
        store_le64_tg(load_le64(src + 8), dst + 8);
        store_le64_tg(load_le64(src + 16), dst + 16);
        store_le64_tg(load_le64(src + 24), dst + 24);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint readBase = 0u;
    uint writeBase = scratchStride;
    uint levelCount = nodeCount;
    while (levelCount > 1) {
        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + readBase + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + writeBase + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        const uint oldReadBase = readBase;
        readBase = writeBase;
        writeBase = oldReadBase;
        levelCount = parentCount;
    }

    if (tid == 0) {
        const threadgroup uchar *result = scratch + readBase;
        store_le64(load_le64_tg(result + 0), root + 0);
        store_le64(load_le64_tg(result + 8), root + 8);
        store_le64(load_le64_tg(result + 16), root + 16);
        store_le64(load_le64_tg(result + 24), root + 24);
    }
}

kernel void sha3_256_merkle_extract_sibling_32(
    const device uchar *nodes [[buffer(0)]],
    device uchar *proof [[buffer(1)]],
    constant MerkleExtractParams &params [[buffer(2)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= 32u || params.nodeIndex >= params.nodeCount) {
        return;
    }

    const uint siblingIndex = params.nodeIndex ^ 1u;
    if (siblingIndex >= params.nodeCount) {
        return;
    }

    proof[params.proofOffset + gid] = nodes[siblingIndex * uint(AZK_FC_PARENT_BYTES) + gid];
}

kernel void sha3_256_merkle_treelet_leaves_specialized(
    const device uchar *leaves [[buffer(0)]],
    device uchar *subtreeRoots [[buffer(1)]],
    constant MerkleTreeletParams &params [[buffer(2)]],
    threadgroup uchar *scratch [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]])
{
    const uint baseLeaf = tgid * params.subtreeLeafCount;
    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    const uint scratchStride = params.subtreeLeafCount * 32u;

    if (tid < params.subtreeLeafCount) {
        const uint leaf = baseLeaf + tid;
        if (leaf < params.leafCount) {
            thread ulong state[25];
            const device uchar *src = leaves + leaf * params.inputStride;
            sha3_256_absorb_oneblock_leaf_specialized(src, inputLength, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint readBase = 0u;
    uint writeBase = scratchStride;
    uint levelCount = params.subtreeLeafCount;
    while (levelCount > 1u) {
        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + readBase + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + writeBase + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        const uint oldReadBase = readBase;
        readBase = writeBase;
        writeBase = oldReadBase;
        levelCount = parentCount;
    }

    if (tid == 0u) {
        device uchar *root = subtreeRoots + tgid * 32;
        const threadgroup uchar *result = scratch + readBase;
        store_le64(load_le64_tg(result + 0), root + 0);
        store_le64(load_le64_tg(result + 8), root + 8);
        store_le64(load_le64_tg(result + 16), root + 16);
        store_le64(load_le64_tg(result + 24), root + 24);
    }
}

kernel void sha3_256_merkle_treelet_roots_opening_leaves_specialized(
    const device uchar *leaves [[buffer(0)]],
    device uchar *subtreeRoots [[buffer(1)]],
    device uchar *proof [[buffer(2)]],
    constant MerkleTreeletOpenParams &params [[buffer(3)]],
    threadgroup uchar *scratch [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]])
{
    if (params.subtreeLeafCount == 0u || params.localLeafIndex >= params.subtreeLeafCount) {
        return;
    }

    const uint baseLeaf = tgid * params.subtreeLeafCount;
    const bool writesOpening = (baseLeaf == params.baseLeaf);
    const uint inputLength = uint(AZK_FC_LEAF_BYTES);
    const uint scratchStride = params.subtreeLeafCount * 32u;

    if (tid < params.subtreeLeafCount) {
        const uint leaf = baseLeaf + tid;
        if (leaf < params.leafCount) {
            thread ulong state[25];
            const device uchar *src = leaves + leaf * params.inputStride;
            sha3_256_absorb_oneblock_leaf_specialized(src, inputLength, state);
            threadgroup uchar *dst = scratch + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    uint readBase = 0u;
    uint writeBase = scratchStride;
    uint levelCount = params.subtreeLeafCount;
    uint localIndex = params.localLeafIndex;
    uint localLevel = 0u;
    while (levelCount > 1u) {
        if (writesOpening) {
            const uint siblingIndex = localIndex ^ 1u;
            for (uint byte = tid; byte < 32u; byte += threadsPerThreadgroup) {
                proof[params.proofOffset + localLevel * 32u + byte] =
                    scratch[readBase + siblingIndex * 32u + byte];
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        const uint parentCount = levelCount >> 1;
        if (tid < parentCount) {
            thread ulong state[25];
            const threadgroup uchar *src = scratch + readBase + tid * 64;
            sha3_256_absorb_fixed_64_tg(src, state);
            threadgroup uchar *dst = scratch + writeBase + tid * 32;
            store_sha3_256_digest_tg(state, dst);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);

        const uint oldReadBase = readBase;
        readBase = writeBase;
        writeBase = oldReadBase;
        levelCount = parentCount;
        localIndex >>= 1;
        localLevel += 1u;
    }

    if (tid == 0u) {
        device uchar *root = subtreeRoots + tgid * 32;
        const threadgroup uchar *result = scratch + readBase;
        store_le64(load_le64_tg(result + 0), root + 0);
        store_le64(load_le64_tg(result + 8), root + 8);
        store_le64(load_le64_tg(result + 16), root + 16);
        store_le64(load_le64_tg(result + 24), root + 24);
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
    if (gid != 0u || params.challengeCount == 0u) {
        return;
    }

    thread ulong state[25];
    for (uint i = 0; i < 25u; ++i) {
        state[i] = transcriptState[i];
    }

    const ulong modulus = ulong(max(params.fieldModulus, 1u));
    const ulong sampleSpace = 0x100000000UL;
    const ulong rejectionLimit = sampleSpace - (sampleSpace % modulus);
    uint produced = 0u;
    ulong candidateIndex = 0u;

    while (produced < params.challengeCount) {
        if (candidateIndex > 0u && (candidateIndex % ulong(SHA3_256_RATE_U32_WORDS)) == 0u) {
            keccak_f1600(state);
        }

        const uint wordIndex = uint(candidateIndex % ulong(SHA3_256_RATE_U32_WORDS));
        const ulong word = state[wordIndex >> 1];
        const ulong candidate = (word >> ((wordIndex & 1u) * 32u)) & 0xffffffffUL;
        candidateIndex += 1u;

        if (candidate < rejectionLimit) {
            challenges[produced] = uint(candidate % modulus);
            produced += 1u;
        }
    }
}

inline uint m31_subtract_modulus_mask(ulong value) {
    return uint(0u) - uint(value >= M31_MODULUS_U64);
}

inline uint m31_reduce_u64(ulong value) {
    ulong reduced = (value & M31_MODULUS_U64) + (value >> 31);
    reduced = (reduced & M31_MODULUS_U64) + (reduced >> 31);
    reduced = (reduced & M31_MODULUS_U64) + (reduced >> 31);
    return uint(reduced - (M31_MODULUS_U64 & ulong(m31_subtract_modulus_mask(reduced))));
}

inline uint m31_add_mod(uint a, uint b) {
    const uint sum = a + b;
    const uint mask = uint(0u) - uint(sum >= M31_MODULUS_U32);
    return sum - (M31_MODULUS_U32 & mask);
}

inline uint m31_sub_mod(uint a, uint b) {
    const uint difference = a - b;
    const uint underflowMask = uint(0u) - uint(a < b);
    return difference + (M31_MODULUS_U32 & underflowMask);
}

inline uint m31_neg_mod(uint value) {
    const uint nonzeroMask = uint(0u) - uint(value != 0u);
    return (M31_MODULUS_U32 - value) & nonzeroMask;
}

inline uint m31_mul_mod(uint a, uint b) {
    return m31_reduce_u64(ulong(a) * ulong(b));
}

inline uint m31_mul_add_mod(uint a, uint b, uint challenge) {
    const ulong value = ulong(a) + ulong(b) * ulong(challenge);
    return m31_reduce_u64(value);
}

inline uint m31_inverse_mod(uint value) {
    uint result = 1u;
    uint power = value;
    uint exponent = M31_MODULUS_U32 - 2u;
    while (exponent > 0u) {
        if ((exponent & 1u) != 0u) {
            result = m31_mul_mod(result, power);
        }
        exponent >>= 1u;
        if (exponent > 0u) {
            power = m31_mul_mod(power, power);
        }
    }
    return result;
}

kernel void m31_vector_arithmetic(
    const device uint *lhs [[buffer(0)]],
    const device uint *rhs [[buffer(1)]],
    device uint *output [[buffer(2)]],
    constant M31VectorParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count || params.fieldModulus != M31_MODULUS_U32) {
        return;
    }

    const uint a = lhs[gid];
    switch (params.operation) {
    case 0u:
        output[gid] = m31_add_mod(a, rhs[gid]);
        break;
    case 1u:
        output[gid] = m31_sub_mod(a, rhs[gid]);
        break;
    case 2u:
        output[gid] = m31_neg_mod(a);
        break;
    case 3u:
        output[gid] = m31_mul_mod(a, rhs[gid]);
        break;
    case 4u:
        output[gid] = m31_mul_mod(a, a);
        break;
    case 5u:
        output[gid] = m31_inverse_mod(a);
        break;
    default:
        output[gid] = 0u;
        break;
    }
}

inline uint2 cm31_add_mod(uint2 a, uint2 b) {
    return uint2(m31_add_mod(a.x, b.x), m31_add_mod(a.y, b.y));
}

inline uint2 cm31_sub_mod(uint2 a, uint2 b) {
    return uint2(m31_sub_mod(a.x, b.x), m31_sub_mod(a.y, b.y));
}

inline uint2 cm31_neg_mod(uint2 value) {
    return uint2(m31_neg_mod(value.x), m31_neg_mod(value.y));
}

inline uint2 cm31_mul_mod(uint2 a, uint2 b) {
    const uint ac = m31_mul_mod(a.x, b.x);
    const uint bd = m31_mul_mod(a.y, b.y);
    const uint sumA = m31_add_mod(a.x, a.y);
    const uint sumB = m31_add_mod(b.x, b.y);
    const uint productOfSums = m31_mul_mod(sumA, sumB);
    return uint2(
        m31_sub_mod(ac, bd),
        m31_sub_mod(m31_sub_mod(productOfSums, ac), bd)
    );
}

inline uint2 cm31_square_mod(uint2 value) {
    const uint sum = m31_add_mod(value.x, value.y);
    const uint difference = m31_sub_mod(value.x, value.y);
    const uint cross = m31_mul_mod(value.x, value.y);
    return uint2(m31_mul_mod(sum, difference), m31_add_mod(cross, cross));
}

inline uint2 cm31_inverse_mod(uint2 value) {
    const uint denominator = m31_add_mod(m31_mul_mod(value.x, value.x), m31_mul_mod(value.y, value.y));
    const uint denominatorInverse = m31_inverse_mod(denominator);
    return uint2(
        m31_mul_mod(value.x, denominatorInverse),
        m31_mul_mod(m31_neg_mod(value.y), denominatorInverse)
    );
}

kernel void cm31_vector_arithmetic(
    const device uint2 *lhs [[buffer(0)]],
    const device uint2 *rhs [[buffer(1)]],
    device uint2 *output [[buffer(2)]],
    constant CM31VectorParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count || params.fieldModulus != M31_MODULUS_U32) {
        return;
    }

    const uint2 a = lhs[gid];
    switch (params.operation) {
    case 0u:
        output[gid] = cm31_add_mod(a, rhs[gid]);
        break;
    case 1u:
        output[gid] = cm31_sub_mod(a, rhs[gid]);
        break;
    case 2u:
        output[gid] = cm31_neg_mod(a);
        break;
    case 3u:
        output[gid] = cm31_mul_mod(a, rhs[gid]);
        break;
    case 4u:
        output[gid] = cm31_square_mod(a);
        break;
    default:
        output[gid] = uint2(0u, 0u);
        break;
    }
}

inline uint2 qm31_non_residue_mul_mod(uint2 value) {
    return cm31_mul_mod(uint2(2u, 1u), value);
}

inline uint4 qm31_from_pairs(uint2 constantPart, uint2 uPart) {
    return uint4(constantPart.x, constantPart.y, uPart.x, uPart.y);
}

inline uint4 qm31_add_mod(uint4 a, uint4 b) {
    return qm31_from_pairs(cm31_add_mod(a.xy, b.xy), cm31_add_mod(a.zw, b.zw));
}

inline uint4 qm31_sub_mod(uint4 a, uint4 b) {
    return qm31_from_pairs(cm31_sub_mod(a.xy, b.xy), cm31_sub_mod(a.zw, b.zw));
}

inline uint4 qm31_neg_mod(uint4 value) {
    return qm31_from_pairs(cm31_neg_mod(value.xy), cm31_neg_mod(value.zw));
}

inline uint4 qm31_mul_mod(uint4 a, uint4 b) {
    const uint2 ac = cm31_mul_mod(a.xy, b.xy);
    const uint2 bd = cm31_mul_mod(a.zw, b.zw);
    const uint2 ad = cm31_mul_mod(a.xy, b.zw);
    const uint2 bc = cm31_mul_mod(a.zw, b.xy);
    return qm31_from_pairs(
        cm31_add_mod(ac, qm31_non_residue_mul_mod(bd)),
        cm31_add_mod(ad, bc)
    );
}

inline uint4 qm31_square_mod(uint4 value) {
    const uint2 aa = cm31_square_mod(value.xy);
    const uint2 bb = cm31_square_mod(value.zw);
    const uint2 ab = cm31_mul_mod(value.xy, value.zw);
    return qm31_from_pairs(
        cm31_add_mod(aa, qm31_non_residue_mul_mod(bb)),
        cm31_add_mod(ab, ab)
    );
}

inline uint4 qm31_inverse_mod(uint4 value) {
    const uint2 aa = cm31_square_mod(value.xy);
    const uint2 bb = cm31_square_mod(value.zw);
    const uint2 denominator = cm31_sub_mod(aa, qm31_non_residue_mul_mod(bb));
    const uint2 denominatorInverse = cm31_inverse_mod(denominator);
    return qm31_from_pairs(
        cm31_mul_mod(value.xy, denominatorInverse),
        cm31_mul_mod(cm31_neg_mod(value.zw), denominatorInverse)
    );
}

inline uint4 qm31_mul_m31_mod(uint4 value, uint scalar) {
    return uint4(
        m31_mul_mod(value.x, scalar),
        m31_mul_mod(value.y, scalar),
        m31_mul_mod(value.z, scalar),
        m31_mul_mod(value.w, scalar)
    );
}

kernel void qm31_vector_arithmetic(
    const device uint4 *lhs [[buffer(0)]],
    const device uint4 *rhs [[buffer(1)]],
    device uint4 *output [[buffer(2)]],
    constant QM31VectorParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.count || params.fieldModulus != M31_MODULUS_U32) {
        return;
    }

    const uint4 a = lhs[gid];
    switch (params.operation) {
    case 0u:
        output[gid] = qm31_add_mod(a, rhs[gid]);
        break;
    case 1u:
        output[gid] = qm31_sub_mod(a, rhs[gid]);
        break;
    case 2u:
        output[gid] = qm31_neg_mod(a);
        break;
    case 3u:
        output[gid] = qm31_mul_mod(a, rhs[gid]);
        break;
    case 4u:
        output[gid] = qm31_square_mod(a);
        break;
    case 5u:
        output[gid] = qm31_inverse_mod(a);
        break;
    default:
        output[gid] = uint4(0u, 0u, 0u, 0u);
        break;
    }
}

kernel void qm31_fri_fold(
    const device uint4 *evaluations [[buffer(0)]],
    const device uint4 *inverseDomainPoints [[buffer(1)]],
    device uint4 *output [[buffer(2)]],
    constant QM31FRIFoldParams &params [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pairCount || params.fieldModulus != M31_MODULUS_U32) {
        return;
    }

    const uint4 positive = evaluations[gid * 2u];
    const uint4 negative = evaluations[gid * 2u + 1u];
    const uint4 evenNumerator = qm31_add_mod(positive, negative);
    const uint4 oddNumerator = qm31_sub_mod(positive, negative);
    const uint4 oddAtSquare = qm31_mul_mod(oddNumerator, inverseDomainPoints[gid]);
    const uint4 challenge = uint4(
        params.challengeA,
        params.challengeB,
        params.challengeC,
        params.challengeD
    );
    const uint4 mixed = qm31_add_mod(evenNumerator, qm31_mul_mod(challenge, oddAtSquare));
    output[gid] = qm31_mul_m31_mod(mixed, 1073741824u);
}

kernel void qm31_fri_fold_challenge_buffer(
    const device uint4 *evaluations [[buffer(0)]],
    const device uint4 *inverseDomainPoints [[buffer(1)]],
    device uint4 *output [[buffer(2)]],
    const device uint4 *challengeWords [[buffer(3)]],
    constant QM31FRIFoldParams &params [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= params.pairCount || params.fieldModulus != M31_MODULUS_U32) {
        return;
    }

    const uint4 positive = evaluations[gid * 2u];
    const uint4 negative = evaluations[gid * 2u + 1u];
    const uint4 evenNumerator = qm31_add_mod(positive, negative);
    const uint4 oddNumerator = qm31_sub_mod(positive, negative);
    const uint4 oddAtSquare = qm31_mul_mod(oddNumerator, inverseDomainPoints[gid]);
    const uint4 mixed = qm31_add_mod(evenNumerator, qm31_mul_mod(challengeWords[0], oddAtSquare));
    output[gid] = qm31_mul_m31_mod(mixed, 1073741824u);
}

inline uint m31_threadgroup_sum(threadgroup uint *scratch, uint tid, uint threadCount) {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = threadCount >> 1; stride > 0u; stride >>= 1) {
        if (tid < stride) {
            scratch[tid] = m31_add_mod(scratch[tid], scratch[tid + stride]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    return scratch[0];
}

kernel void m31_dot_product_partials(
    const device uint *lhs [[buffer(0)]],
    const device uint *rhs [[buffer(1)]],
    device uint *partials [[buffer(2)]],
    constant M31DotProductParams &params [[buffer(3)]],
    threadgroup uint *scratch [[threadgroup(0)]],
    uint tid [[thread_index_in_threadgroup]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]])
{
    if (params.fieldModulus != M31_MODULUS_U32 ||
        params.elementsPerThreadgroup == 0u ||
        params.threadsPerThreadgroup == 0u) {
        return;
    }

    const uint groupIndex = threadgroupPosition.x;
    const uint base = groupIndex * params.elementsPerThreadgroup;
    uint accumulator = 0u;
    if (base < params.count) {
        const uint span = min(params.elementsPerThreadgroup, params.count - base);
        const uint limit = base + span;
        uint index = base + tid;
        while (index < limit) {
            accumulator = m31_add_mod(accumulator, m31_mul_mod(lhs[index], rhs[index]));
            const uint next = index + params.threadsPerThreadgroup;
            if (next <= index) {
                break;
            }
            index = next;
        }
    }

    scratch[tid] = accumulator;
    const uint reduced = m31_threadgroup_sum(scratch, tid, params.threadsPerThreadgroup);
    if (tid == 0u) {
        partials[groupIndex] = reduced;
    }
}

kernel void m31_sum_partials(
    const device uint *input [[buffer(0)]],
    device uint *output [[buffer(1)]],
    constant M31DotProductParams &params [[buffer(2)]],
    threadgroup uint *scratch [[threadgroup(0)]],
    uint tid [[thread_index_in_threadgroup]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]])
{
    if (params.fieldModulus != M31_MODULUS_U32 ||
        params.elementsPerThreadgroup == 0u ||
        params.threadsPerThreadgroup == 0u) {
        return;
    }

    const uint groupIndex = threadgroupPosition.x;
    const uint base = groupIndex * params.elementsPerThreadgroup;
    uint accumulator = 0u;
    if (base < params.count) {
        const uint span = min(params.elementsPerThreadgroup, params.count - base);
        const uint limit = base + span;
        uint index = base + tid;
        while (index < limit) {
            accumulator = m31_add_mod(accumulator, input[index]);
            const uint next = index + params.threadsPerThreadgroup;
            if (next <= index) {
                break;
            }
            index = next;
        }
    }

    scratch[tid] = accumulator;
    const uint reduced = m31_threadgroup_sum(scratch, tid, params.threadsPerThreadgroup);
    if (tid == 0u) {
        output[groupIndex] = reduced;
    }
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

    if (params.fieldModulus != M31_MODULUS_U32) {
        return;
    }
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = m31_add_mod(a, b);
    next[gid] = m31_mul_add_mod(a, b, params.challenge);
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

    if (params.fieldModulus != M31_MODULUS_U32) {
        return;
    }
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = m31_add_mod(a, b);
    next[gid] = m31_mul_add_mod(a, b, params.challenge);
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

    if (params.fieldModulus != M31_MODULUS_U32) {
        return;
    }
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    coefficients[gid] = m31_add_mod(a, b);
    next[gid] = m31_mul_add_mod(a, b, params.challenge);
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

    if (params.fieldModulus != M31_MODULUS_U32) {
        return;
    }
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
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

    if (params.fieldModulus != M31_MODULUS_U32) {
        return;
    }
    const uint a = current[gid * 2];
    const uint b = current[gid * 2 + 1];
    next[gid] = m31_mul_add_mod(a, b, challenge[0]);
}
