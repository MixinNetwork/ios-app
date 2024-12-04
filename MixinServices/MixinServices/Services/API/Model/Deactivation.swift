import Foundation

public struct Deactivation {
    
    public let requestedAt: Date
    public let effectiveAt: Date
    
    init?(requestedAt: String?, effectiveAt: String?) {
        guard
            let requestedAtDate = requestedAt?.toUTCDate(),
            let effectiveAtDate = effectiveAt?.toUTCDate()
        else {
            return nil
        }
        self.requestedAt = requestedAtDate
        self.effectiveAt = effectiveAtDate
    }
    
}
