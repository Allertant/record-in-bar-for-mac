import Foundation

enum Base64Coder {
    static func encode(_ string: String) -> String {
        guard !string.isEmpty else { return "" }
        return Data(string.utf8).base64EncodedString()
    }

    static func decode(_ string: String) -> String {
        guard !string.isEmpty else { return "" }
        guard let data = Data(base64Encoded: string) else {
            return string
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func isEncoded(_ string: String) -> Bool {
        guard !string.isEmpty, let data = Data(base64Encoded: string) else {
            return false
        }
        return Data(decode(string).utf8) == data
    }
}
