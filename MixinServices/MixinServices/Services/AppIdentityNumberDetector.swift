import Foundation

public enum AppIdentityNumberDetector {
    
    private static let appIdentityNumberRegex = try? NSRegularExpression(pattern: #"(?<=^|\D)7000\d{6}(?=$|\D)"#, options: [])
    
    public static func detect(in text: String, range: NSRange? = nil) -> [NSRange: URL] {
        guard let regex = appIdentityNumberRegex else {
            return [:]
        }
        let nsText = text as NSString
        let detectingRange = range ?? NSRange(location: 0, length: nsText.length)
        return regex.matches(
            in: text,
            range: detectingRange
        ).reduce(into: [:]) { results, detected in
            guard detected.range.location != NSNotFound else {
                return
            }
            let identityNumber = nsText.substring(with: detected.range)
            guard let url = MixinInternalURL.identityNumber(identityNumber).url else {
                return
            }
            results[detected.range] = url
        }
    }
    
}
