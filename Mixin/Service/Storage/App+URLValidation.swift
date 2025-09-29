import Foundation
import MixinServices

extension App {
    
    func resourcePatterns(accepts url: URL) -> Bool {
        guard let resourcePatterns else {
            return false
        }
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        return resourcePatterns.contains { pattern in
            guard let rule = URL(string: pattern) else {
                return false
            }
            let schemeMatches = rule.scheme?.lowercased() == scheme
            let hostMatches = rule.host?.lowercased() == host
            let pathMatches = url.path.hasPrefix(rule.path)
            return schemeMatches && hostMatches && pathMatches
        }
    }
    
}
