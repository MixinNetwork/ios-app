import Foundation

struct ProfileMenuItem {
    
    struct Style: OptionSet {
        let rawValue: Int
        static let destructive = Style(rawValue: 1 << 0)
    }
    
    let title: String
    let subtitle: String?
    let style: Style
    let action: Selector
    
}
