import Foundation

public extension Data {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
