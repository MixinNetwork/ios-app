import Foundation

public struct SQLEscaping {
    
    public static let escapeCharacter: Unicode.Scalar = "/"
    
    public static func escape(_ string: String) -> String {
        string.replacingOccurrences(of: "/", with: "//")
            .replacingOccurrences(of: "%", with: "/%")
            .replacingOccurrences(of: "_", with: "/_")
            .replacingOccurrences(of: "[", with: "/[")
            .replacingOccurrences(of: "]", with: "/]")
    }
    
}
