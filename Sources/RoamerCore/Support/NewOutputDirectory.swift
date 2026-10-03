import Darwin
import Foundation

package enum NewOutputDirectory {
    package static func create(path: String) throws -> URL {
        guard !path.isEmpty, !path.utf8.contains(0) else {
            throw RoamerError.message("输出目录不能为空或包含 NUL")
        }
        let directory = URL(fileURLWithPath: path).standardizedFileURL
        let result = directory.withUnsafeFileSystemRepresentation { representation in
            guard let representation else { return Int32(-1) }
            return mkdir(representation, 0o700)
        }
        guard result == 0 else {
            throw RoamerError.message(
                "无法创建新的输出目录 \(directory.path)：\(String(cString: strerror(errno)))；父目录须存在，旧路径不会覆盖"
            )
        }
        return directory
    }
}
