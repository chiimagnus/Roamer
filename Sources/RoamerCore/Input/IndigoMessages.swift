import Darwin
import Foundation

private typealias ButtonBuilder = @convention(c) (
    Int32,
    Int32,
    Int32
) -> UnsafeMutableRawPointer?

final class IndigoMessages {
    private let runtime: PrivateRuntime

    init(runtime: PrivateRuntime) {
        self.runtime = runtime
    }

    func homeButton(eventType: Int32) throws -> UnsafeMutableRawPointer {
        let build = try runtime.symbol(
            "IndigoHIDMessageForButton",
            as: ButtonBuilder.self
        )
        guard let message = build(0, eventType, 0x33) else {
            throw RoamerError.message("无法构造 Home HID 事件")
        }
        return message
    }

    func pose(yawDegrees: Double) throws -> UnsafeMutableRawPointer {
        let message = try palomaMessage()
        writeBytes(UInt32(300), to: message, offset: 0x30)

        let halfYaw = yawDegrees * .pi / 360
        writeBytes(Float(0), to: message, offset: 0x54)
        writeBytes(Float(0), to: message, offset: 0x58)
        writeBytes(Float(0), to: message, offset: 0x5c)
        writeBytes(Float(0), to: message, offset: 0x64)
        writeBytes(Float(sin(halfYaw)), to: message, offset: 0x68)
        writeBytes(Float(0), to: message, offset: 0x6c)
        writeBytes(Float(cos(halfYaw)), to: message, offset: 0x70)
        return message
    }

    func collection(
        yawDegrees: Double,
        pitchDegrees: Double,
        pinchingRight: Bool
    ) throws -> UnsafeMutableRawPointer {
        let message = try palomaMessage()

        writeBytes(UInt32(302), to: message, offset: 0x30)
        writeBytes(UInt32(3), to: message, offset: 0x34)
        writeBytes(UInt8(0), to: message, offset: 0x38)
        writeBytes(UInt8(2), to: message, offset: 0x39)
        writeBytes(UInt8(0), to: message, offset: 0x3a)
        writeBytes(UInt32(3), to: message, offset: 0x3b)
        writeBytes(UInt8(pinchingRight ? 1 : 0), to: message, offset: 0x3f)
        writeBytes(UInt8(1), to: message, offset: 0x40)
        writeBytes(UInt8(0), to: message, offset: 0x41)
        writeBytes(UInt8(0), to: message, offset: 0x42)
        writeBytes(UInt16(0), to: message, offset: 0x43)
        writeBytes(UInt16(0), to: message, offset: 0x45)

        let yaw = yawDegrees * .pi / 180
        let pitch = pitchDegrees * .pi / 180
        let directionX = Float(sin(yaw) * cos(pitch))
        let directionY = Float(sin(pitch))
        let directionZ = Float(-cos(yaw) * cos(pitch))

        writeBytes(Float(0), to: message, offset: 0x47)
        writeBytes(Float(0), to: message, offset: 0x4b)
        writeBytes(Float(0), to: message, offset: 0x4f)

        writeBytes(directionX, to: message, offset: 0x57)
        writeBytes(directionY, to: message, offset: 0x5b)
        writeBytes(directionZ, to: message, offset: 0x5f)

        // 左右手 pose 保持 identity；已验证足以完成 gaze + right-hand pinch selection。
        writeBytes(Float(1), to: message, offset: 0x83)
        writeBytes(Float(1), to: message, offset: 0xa3)

        return message
    }

    private func palomaMessage() throws -> UnsafeMutableRawPointer {
        guard let message = calloc(1, 0xc0) else {
            throw RoamerError.message("无法分配 Paloma HID message")
        }

        writeBytes(UInt32(0xa0), to: message, offset: 0x18)
        writeBytes(UInt8(1), to: message, offset: 0x1c)
        writeBytes(UInt32(1), to: message, offset: 0x20)
        writeBytes(UInt64(mach_absolute_time()), to: message, offset: 0x24)
        return message
    }

    private func writeBytes<T>(
        _ value: T,
        to message: UnsafeMutableRawPointer,
        offset: Int
    ) {
        var copy = value
        withUnsafeBytes(of: &copy) { bytes in
            guard let base = bytes.baseAddress else {
                return
            }
            message.advanced(by: offset).copyMemory(
                from: base,
                byteCount: bytes.count
            )
        }
    }
}
