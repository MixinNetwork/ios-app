import Foundation

public enum Web3Reputation {
    
    public enum Level: Int {
        case good = 12
        case verified = 11
        case unknown = 10
        case spam = 1
        case scam = 0
    }
    
    public enum FilterOption: Int, CaseIterable {
        
        case spam
        
        public static func options(token: Web3Token) -> Set<Web3Reputation.FilterOption> {
            let options: Set<Web3Reputation.FilterOption>
            if token.level <= Web3Reputation.Level.spam.rawValue {
                options = [.spam]
            } else {
                options = []
            }
            return options
        }
        
    }
    
}
