import Foundation

package struct CrownRotation: Equatable, Sendable {
    package let stepCount: Int
    package let step: Float

    package init(delta: Int) throws {
        guard (-20...20).contains(delta) else {
            throw RoamerError.message("crown delta 必须在 -20...20 之间")
        }

        stepCount = Int(delta.magnitude)
        if delta > 0 {
            step = 0.05
        } else if delta < 0 {
            step = -0.05
        } else {
            step = 0
        }
    }
}
