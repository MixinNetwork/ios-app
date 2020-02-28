import Foundation

public enum MessageMentionDetector {
    
    private static let regex = try? NSRegularExpression(pattern: "@([0-9]{4,})", options: [])
    
    public static func identityNumbers(from text: String) -> [String] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let matches = regex?.matches(in: text, options: [], range: range) else {
            return []
        }
        var numbers = Set<String>()
        for match in matches {
            let range = match.range(at: 1)
            let number = nsText.substring(with: range)
            numbers.insert(number)
        }
        return Array(numbers)
    }
    
}
