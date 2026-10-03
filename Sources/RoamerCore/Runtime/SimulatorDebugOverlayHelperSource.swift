enum SimulatorDebugOverlayHelperSource {
    static let source = #"""
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>

static const uint64_t RoamerEntityBounds = 0x1;
static const uint64_t RoamerEntityAxis = 0x4;
static dispatch_semaphore_t RoamerSemaphore;
static BOOL RoamerBooleanValue;
static NSError *RoamerErrorValue;
static volatile sig_atomic_t RoamerInterrupted = 0;

static void RoamerSignalHandler(int signalNumber) {
    RoamerInterrupted = signalNumber;
}

static BOOL RoamerWait(NSError **error) {
    if (dispatch_semaphore_wait(
        RoamerSemaphore,
        dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)
    ) != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"RoamerDebugOverlay" code:1 userInfo:@{
                NSLocalizedDescriptionKey: @"RealitySimulation request timed out"
            }];
        }
        return NO;
    }
    if (RoamerErrorValue) {
        if (error) *error = RoamerErrorValue;
        return NO;
    }
    return YES;
}

static BOOL RoamerGetOption(id service, NSString *bundleID, uint64_t option, BOOL *value, NSError **error) {
    RoamerSemaphore = dispatch_semaphore_create(0);
    RoamerBooleanValue = NO;
    RoamerErrorValue = nil;
    void (^completion)(BOOL, NSError *) = ^(BOOL result, NSError *requestError) {
        RoamerBooleanValue = result;
        RoamerErrorValue = requestError;
        dispatch_semaphore_signal(RoamerSemaphore);
    };
    ((void (*)(id, SEL, uint64_t, id, id, id))objc_msgSend)(
        service,
        NSSelectorFromString(@"getEntityDebugOption:enabledForBundleID:orSceneID:completion:"),
        option,
        bundleID,
        nil,
        completion
    );
    if (!RoamerWait(error)) return NO;
    *value = RoamerBooleanValue;
    return YES;
}

static BOOL RoamerSetOption(id service, NSString *bundleID, uint64_t option, BOOL enabled, NSError **error) {
    RoamerSemaphore = dispatch_semaphore_create(0);
    RoamerErrorValue = nil;
    void (^completion)(NSError *) = ^(NSError *requestError) {
        RoamerErrorValue = requestError;
        dispatch_semaphore_signal(RoamerSemaphore);
    };
    ((void (*)(id, SEL, uint64_t, BOOL, id, id, id))objc_msgSend)(
        service,
        NSSelectorFromString(@"setEntityDebugOption:enabled:forBundleID:orSceneID:completion:"),
        option,
        enabled,
        bundleID,
        nil,
        completion
    );
    return RoamerWait(error);
}

static BOOL RoamerRenderFence(id service, NSError **error) {
    RoamerSemaphore = dispatch_semaphore_create(0);
    RoamerErrorValue = nil;
    void (^completion)(id, id, NSError *) = ^(id execution, id scheduling, NSError *requestError) {
        (void)execution;
        (void)scheduling;
        RoamerErrorValue = requestError;
        dispatch_semaphore_signal(RoamerSemaphore);
    };
    ((void (*)(id, SEL, uint64_t, id))objc_msgSend)(
        service,
        NSSelectorFromString(@"collectGPUPerformanceStatisticsWithFrameCount:completion:"),
        1,
        completion
    );
    return RoamerWait(error);
}

static BOOL RoamerRequireMethod(Class cls, NSString *name, const char *encoding) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(name));
    return method && strcmp(method_getTypeEncoding(method), encoding) == 0;
}

static BOOL RoamerRestore(
    id service,
    NSString *bundleID,
    BOOL changedAxis,
    BOOL changedBounds,
    NSError **error
) {
    BOOL okay = YES;
    NSError *first = nil;
    if (changedBounds && !RoamerSetOption(service, bundleID, RoamerEntityBounds, NO, &first)) {
        okay = NO;
    }
    NSError *axisError = nil;
    if (changedAxis && !RoamerSetOption(service, bundleID, RoamerEntityAxis, NO, &axisError)) {
        if (!first) first = axisError;
        okay = NO;
    }
    NSError *fenceError = nil;
    if ((changedAxis || changedBounds) && !RoamerRenderFence(service, &fenceError)) {
        if (!first) first = fenceError;
        okay = NO;
    }
    if (!okay && error) *error = first;
    return okay;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        setbuf(stdout, NULL);
        if (argc != 2 || argv[1][0] == '\0') {
            fprintf(stderr, "expected bundle ID\n");
            return 64;
        }

        signal(SIGINT, RoamerSignalHandler);
        signal(SIGTERM, RoamerSignalHandler);

        const char *framework = "/System/Library/PrivateFrameworks/RealitySimulationServices.framework/RealitySimulationServices";
        if (!dlopen(framework, RTLD_NOW | RTLD_GLOBAL)) {
            fprintf(stderr, "RealitySimulationServices unavailable: %s\n", dlerror());
            return 2;
        }

        Class cls = NSClassFromString(@"RSSDebugService");
        if (!cls ||
            !RoamerRequireMethod(cls,
                @"getEntityDebugOption:enabledForBundleID:orSceneID:completion:",
                "v48@0:8Q16@24@32@?40") ||
            !RoamerRequireMethod(cls,
                @"setEntityDebugOption:enabled:forBundleID:orSceneID:completion:",
                "v52@0:8Q16B24@28@36@?44") ||
            !RoamerRequireMethod(cls,
                @"collectGPUPerformanceStatisticsWithFrameCount:completion:",
                "v32@0:8Q16@?24")) {
            fprintf(stderr, "verified RSSDebugService ABI unavailable\n");
            return 3;
        }

        NSString *bundleID = [NSString stringWithUTF8String:argv[1]];
        id service = [[cls alloc] init];
        BOOL originalAxis = NO;
        BOOL originalBounds = NO;
        BOOL changedAxis = NO;
        BOOL changedBounds = NO;
        NSError *error = nil;

        if (!RoamerGetOption(service, bundleID, RoamerEntityAxis, &originalAxis, &error) ||
            !RoamerGetOption(service, bundleID, RoamerEntityBounds, &originalBounds, &error)) {
            fprintf(stderr, "failed to read original debug options: %s\n", error.description.UTF8String);
            return 4;
        }

        if (!originalAxis) {
            if (!RoamerSetOption(service, bundleID, RoamerEntityAxis, YES, &error)) {
                fprintf(stderr, "failed to enable entity axis: %s\n", error.description.UTF8String);
                return 5;
            }
            changedAxis = YES;
        }
        if (!originalBounds) {
            if (!RoamerSetOption(service, bundleID, RoamerEntityBounds, YES, &error)) {
                NSError *cleanup = nil;
                RoamerRestore(service, bundleID, changedAxis, NO, &cleanup);
                fprintf(stderr, "failed to enable entity bounds: %s; cleanup: %s\n",
                    error.description.UTF8String,
                    cleanup ? cleanup.description.UTF8String : "ok");
                return 5;
            }
            changedBounds = YES;
        }

        if (!RoamerRenderFence(service, &error)) {
            NSError *cleanup = nil;
            RoamerRestore(service, bundleID, changedAxis, changedBounds, &cleanup);
            fprintf(stderr, "render fence failed: %s; cleanup: %s\n",
                error.description.UTF8String,
                cleanup ? cleanup.description.UTF8String : "ok");
            return 6;
        }

        printf("{\"state\":\"ready\",\"originalAxis\":%s,\"originalBounds\":%s}\n",
            originalAxis ? "true" : "false",
            originalBounds ? "true" : "false");

        struct pollfd descriptor = { STDIN_FILENO, POLLIN | POLLHUP, 0 };
        int result;
        do {
            result = poll(&descriptor, 1, 60000);
        } while (result < 0 && errno == EINTR && !RoamerInterrupted);
        if (result > 0) {
            char byte;
            (void)read(STDIN_FILENO, &byte, 1);
        }

        NSError *cleanup = nil;
        BOOL restored = RoamerRestore(service, bundleID, changedAxis, changedBounds, &cleanup);
        if (!restored) {
            fprintf(stderr, "failed to restore debug options: %s\n", cleanup.description.UTF8String);
            return 7;
        }
        printf("{\"state\":\"restored\"}\n");
        if (RoamerInterrupted) return 128 + RoamerInterrupted;
        if (result == 0) return 8;
        return 0;
    }
}
"""#
}
