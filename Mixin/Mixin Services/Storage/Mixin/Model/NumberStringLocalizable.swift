
public protocol NumberStringLocalizable {
    func localizedNumberString(_ str: String) -> String
}

public extension NumberStringLocalizable {
    
    func localizedNumberString(_ str: String) -> String {
        if let decimalSeparator = Locale.current.decimalSeparator, decimalSeparator != "." {
            return str.replacingOccurrences(of: ".", with: decimalSeparator)
        } else {
            return str
        }
    }
    
}
