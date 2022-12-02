import Foundation

extension String {
    
    func substring(with range: NSRange) -> String {
        let nsString = self as NSString
        return nsString.substring(with: range)
    }
    
    func nsRange(from range: Range<String.Index>) -> NSRange {
        let utf16view = self.utf16
        let from = range.lowerBound.samePosition(in: utf16view) ?? self.startIndex
        let to = range.upperBound.samePosition(in: utf16view) ?? self.endIndex
        return NSRange(location: utf16view.distance(from: utf16view.startIndex, to: from), length: utf16view.distance(from: from, to: to))
    }
    
}

extension NSRegularExpression {
    
    func matches(in string: String, options: NSRegularExpression.MatchingOptions = [], range: Range<String.Index>? = nil) -> [NSTextCheckingResult] {
        let range = range ?? string.startIndex..<string.endIndex
        let nsRange = string.nsRange(from: range)
        return matches(in: string, options: options, range: nsRange)
    }
    
    func rangeOfFirstMatch(in string: String, options: NSRegularExpression.MatchingOptions = [], range: Range<String.Index>? = nil) -> Range<String.Index>? {
        let range = range ?? string.startIndex..<string.endIndex
        let nsRange = string.nsRange(from: range)
        let match = rangeOfFirstMatch(in: string, options: options, range: nsRange)
        guard
            let from16 = string.utf16.index(string.utf16.startIndex, offsetBy: match.location, limitedBy: string.utf16.endIndex),
            let to16 = string.utf16.index(from16, offsetBy: match.length, limitedBy: string.utf16.endIndex),
            let from = String.Index(from16, within: string),
            let to = String.Index(to16, within: string)
        else {
            return nil
        }
        return from..<to
    }
    
    func stringByReplacingMatches(in string: String, options: NSRegularExpression.MatchingOptions = [], range: Range<String.Index>? = nil, withTemplate templ: String) -> String {
        let range = range ?? string.startIndex..<string.endIndex
        let nsRange = string.nsRange(from: range)
        return stringByReplacingMatches(in: string, options: options, range: nsRange, withTemplate: templ)
    }
    
}
