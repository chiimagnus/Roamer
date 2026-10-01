#ifndef ROAMER_PRIVATE_ABI_H
#define ROAMER_PRIVATE_ABI_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

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
);

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
);

#ifdef __cplusplus
}
#endif

#endif
