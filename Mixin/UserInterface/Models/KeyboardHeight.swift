import CoreGraphics

struct KeyboardHeight {
    
    static var last = `default`
    
    static let `default` = defaultHeights[.current] ?? 271
    static let minReasonable = `default` - 44
    static let maxReasonable = `default` + 44
    
    private static let defaultHeights: [ScreenSize: CGFloat] = [
        .inch6_5: 346,
        .inch6_1: 346,
        .inch5_8: 335,
        .inch5_5: 271,
        .inch4_7: 260,
        .inch4: 253,
        .inch3_5: 261
    ]
    
}
