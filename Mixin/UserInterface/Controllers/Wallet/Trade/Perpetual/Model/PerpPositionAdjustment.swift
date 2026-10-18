import Foundation

enum PerpPositionAdjustment {
    
    static func change(from before: String, to after: String) -> String {
        let before = before.replacingOccurrences(of: " ", with: "\u{00A0}")
        let after = after.replacingOccurrences(of: " ", with: "\u{00A0}")
        return before + "\u{200B}  →  \u{200B}" + after
    }
    
}
