import Foundation

public enum MessageMentionDetector {
    
    private static let regex = try? NSRegularExpression(pattern: "@([0-9]+)", options: [])
    
    public static func mentionedIdentityNumbers(from text: String) -> [String] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let matches = regex?.matches(in: text, options: [], range: range) else {
            return []
        }
        return matches
            .map({ $0.range(at: 1) })
            .map(nsText.substring)
    }
    
}
