import Darwin
import Foundation
import ObjectiveC.runtime

guard dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW | RTLD_GLOBAL) != nil,
      let nativeClass = NSClassFromString("AXPTranslatorRequest"),
      let allocated = (nativeClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
      let request = allocated.perform(NSSelectorFromString("init"))?.takeUnretainedValue() as? NSObject
else { fatalError("AX request metadata unavailable") }

if ProcessInfo.processInfo.environment["ROAMER_AX_METADATA_PAUSE"] == "1" {
    raise(SIGSTOP)
}

for requestType in 0..<25 {
    request.setValue(requestType, forKey: "requestType")
    print("TYPE", requestType, request.description)
}
request.setValue(2, forKey: "requestType")
for attributeType in 0..<120 {
    request.setValue(attributeType, forKey: "attributeType")
    print("ATTRIBUTE", attributeType, request.description)
}
