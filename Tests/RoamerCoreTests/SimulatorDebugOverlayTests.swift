import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorDebugOverlayTests: XCTestCase {
    func testLateCompletionCannotCompleteTheNextRequest() throws {
        try runHelperCheck(#"""
        id service = [RSSDebugService new];
        NSError *error = nil;
        assert(!RoamerSetOption(service, @"late", RoamerEntityAxis, YES, &error));
        error = nil;
        assert(RoamerSetOption(service, @"late", RoamerEntityAxis, NO, &error));
        assert(![(RSSDebugService *)service axis]);
        """#)
    }

    func testFailedEnablesRestoreAllAttemptedOptions() throws {
        for scenario in ["timeout-axis", "timeout-bounds", "error-bounds"] {
            try runHelperCheck("""
            const char *arguments[] = {"overlay-test", "\(scenario)"};
            assert(RoamerHelperMain(2, arguments) == 5);
            assert(!lastService.axis && !lastService.bounds);
            """)
        }
    }

    func testNormalAndAlreadyEnabledOptionsKeepTheirOriginalValues() throws {
        for scenario in ["normal", "original-axis"] {
            try runHelperCheck("""
            const char *arguments[] = {"overlay-test", "\(scenario)"};
            assert(RoamerHelperMain(2, arguments) == 0);
            assert(lastService.axis == \(scenario == "original-axis" ? "YES" : "NO"));
            assert(!lastService.bounds);
            """)
        }
    }

    private func runHelperCheck(_ check: String) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("roamer-overlay-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("helper-test.m")
        let executable = directory.appendingPathComponent("helper-test")
        let production = SimulatorDebugOverlayHelperSource.source
            .replacingOccurrences(of: "5 * NSEC_PER_SEC", with: "100 * NSEC_PER_MSEC")
            .replacingOccurrences(
                of: "/System/Library/PrivateFrameworks/RealitySimulationServices.framework/RealitySimulationServices",
                with: "/usr/lib/libobjc.A.dylib"
            )
        let main = """
        #undef main
        int main(void) {
            @autoreleasepool {
                \(check)
                puts("CHECK PASS");
            }
            return 0;
        }
        """
        try Data((Self.service + "\n#define main RoamerHelperMain\n" + production + "\n" + main).utf8)
            .write(to: source)
        _ = try ProcessRunner.run("/usr/bin/xcrun", [
            "--sdk", "macosx", "clang", "-fobjc-arc", "-fblocks", source.path,
            "-framework", "Foundation", "-o", executable.path
        ])
        let result = try ProcessRunner.run("/bin/sh", ["-c", "exec \"$1\" </dev/null", "sh", executable.path])
        XCTAssertTrue(result.stdout.contains("CHECK PASS"))
    }

    private static let service = #"""
    #import <Foundation/Foundation.h>
    #include <assert.h>
    @interface RSSDebugService : NSObject
    @property BOOL axis;
    @property BOOL bounds;
    @end
    static RSSDebugService *lastService;
    @implementation RSSDebugService
    - (instancetype)init {
        if ((self = [super init])) lastService = self;
        return self;
    }
    - (void)getEntityDebugOption:(uint64_t)option enabledForBundleID:(NSString *)bundle
        orSceneID:(id)scene completion:(void (^)(BOOL, NSError *))completion {
        if ([bundle isEqualToString:@"original-axis"]) self.axis = YES;
        completion(option == 4 ? self.axis : self.bounds, nil);
    }
    - (void)setEntityDebugOption:(uint64_t)option enabled:(BOOL)enabled
        forBundleID:(NSString *)bundle orSceneID:(id)scene completion:(void (^)(NSError *))completion {
        if ([bundle isEqualToString:@"late"]) {
            if (enabled) self.axis = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (enabled ? 150 : 80) * NSEC_PER_MSEC),
                dispatch_get_global_queue(0, 0), ^{
                    if (!enabled) self.axis = NO;
                    completion(nil);
                });
            return;
        }
        if (option == 4) self.axis = enabled;
        else self.bounds = enabled;
        if (enabled && (([bundle isEqualToString:@"timeout-axis"] && option == 4) ||
            ([bundle isEqualToString:@"timeout-bounds"] && option == 1))) return;
        if (enabled && [bundle isEqualToString:@"error-bounds"] && option == 1) {
            completion([NSError errorWithDomain:@"test" code:1 userInfo:nil]);
            return;
        }
        completion(nil);
    }
    - (void)collectGPUPerformanceStatisticsWithFrameCount:(uint64_t)count
        completion:(void (^)(id, id, NSError *))completion {
        completion(nil, nil, nil);
    }
    @end
    """#
}
