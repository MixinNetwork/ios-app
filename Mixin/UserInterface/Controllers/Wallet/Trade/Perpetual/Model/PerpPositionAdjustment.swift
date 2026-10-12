import Foundation

enum PerpPositionAdjustment {
    
    static func change(from before: String, to after: String) -> String {
        before + "  →  " + after
    }
    
}
