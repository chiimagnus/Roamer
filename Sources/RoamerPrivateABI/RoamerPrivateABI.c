#include "RoamerPrivateABI.h"

#include <simd/simd.h>

typedef struct {
    simd_float4 origin;
    simd_float4 direction;
} RoamerPalomaRay;

typedef void *(*RoamerPalomaPoseBuilder)(
    uint32_t,
    simd_float3,
    simd_float4
);

typedef void *(*RoamerPalomaCollectionBuilder)(
    uint32_t,
    const RoamerPalomaRay *,
    uint8_t,
    int32_t,
    int32_t,
    uint16_t,
    simd_float3,
    simd_float4,
    int32_t,
    int32_t,
    simd_float3,
    simd_float4,
    uint16_t
);

void *RoamerBuildPalomaPose(
    void *builder,
    uint32_t eventKind,
    float positionX,
    float positionY,
    float positionZ,
    float quaternionX,
    float quaternionY,
    float quaternionZ,
    float quaternionW
) {
    RoamerPalomaPoseBuilder build = (RoamerPalomaPoseBuilder)builder;
    return build(
        eventKind,
        (simd_float3){ positionX, positionY, positionZ },
        (simd_float4){ quaternionX, quaternionY, quaternionZ, quaternionW }
    );
}

void *RoamerBuildPalomaCollection(
    void *builder,
    uint32_t eventKind,
    float originX,
    float originY,
    float originZ,
    float directionX,
    float directionY,
    float directionZ,
    bool pinchingRight,
    float rightHandX,
    float rightHandY,
    float rightHandZ
) {
    RoamerPalomaCollectionBuilder build = (RoamerPalomaCollectionBuilder)builder;
    RoamerPalomaRay ray = {
        .origin = { originX, originY, originZ, 0 },
        .direction = { directionX, directionY, directionZ, 0 },
    };

    return build(
        eventKind,
        &ray,
        0,
        0,
        0,
        0,
        (simd_float3){ 0, 0, 0 },
        (simd_float4){ 0, 0, 0, 1 },
        pinchingRight ? 1 : 0,
        0,
        (simd_float3){ rightHandX, rightHandY, rightHandZ },
        (simd_float4){ 0, 0, 0, 1 },
        0
    );
}
