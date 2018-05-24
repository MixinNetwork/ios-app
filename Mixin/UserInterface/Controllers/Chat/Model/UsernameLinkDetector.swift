import UIKit

struct EmbeddedUsernameDetector {
    
    struct Username {
        let range: NSRange
        let url: URL
        let color: UIColor?
    }
    
    static let usernameRegex = try? NSRegularExpression(pattern: "^<a(.*?)href=\"?(mixin://?[^\"]+)\"?(.*?)>(.+?)</a>", options: .caseInsensitive)
    static let colorRegex = try? NSRegularExpression(pattern: "color=\"#([0-9a-fA-F]{6})\"", options: .caseInsensitive)
    
    static func stringByExtractingEmbeddedUsername(in str: String) -> (String, Username?) {
        guard str.hasPrefix("<a"), let usernameRegex = usernameRegex else {
            return (str, nil)
        }
        let mutableStr = NSMutableString(string: str)
        let fullRange = NSRange(location: 0, length: mutableStr.length)
        guard let match = usernameRegex.firstMatch(in: str, options: [], range: fullRange), match.numberOfRanges == usernameRegex.numberOfCaptureGroups + 1 else {
            return (str, nil)
        }
        let urlRange = match.range(at: 2)
        let urlString = mutableStr.substring(with: urlRange)
        guard let url = URL(string: urlString), url.scheme == MixinURL.scheme else {
            return (str, nil)
        }
        let name = mutableStr.substring(with: match.range(at: 4))
        
        var color: UIColor?
        let otherAttributes = mutableStr.substring(with: match.range(at: 1)) + mutableStr.substring(with: match.range(at: 3))
        let otherAttributesFullRange = NSRange(location: 0, length: (otherAttributes as NSString).length)
        if let colorRegex = colorRegex, let match = colorRegex.firstMatch(in: otherAttributes, options: [], range: otherAttributesFullRange), match.numberOfRanges == colorRegex.numberOfCaptureGroups + 1 {
            let hexString = (otherAttributes as NSString).substring(with: match.range(at: 1))
            color = UIColor(hexString: hexString)
        }
        
        let taggedUsernameRange = match.range(at: 0)
        mutableStr.replaceCharacters(in: taggedUsernameRange, with: name)
        let nameLength = (name as NSString).length
        let range = NSRange(location: taggedUsernameRange.location, length: nameLength)
        let username = Username(range: range, url: url, color: color)
        
        return (mutableStr as String, username)
    }
    
}
