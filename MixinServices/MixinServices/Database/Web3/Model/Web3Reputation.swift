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
        case unknown
        case spam
    }
    
}
