import Foundation

internal func localized(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

internal func localized(_ key: String, arguments: [String]) -> String {
    let format = NSLocalizedString(key, comment: "")
    return String(format: format, arguments: arguments)
}
