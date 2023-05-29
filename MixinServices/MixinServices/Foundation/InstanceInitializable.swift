import Foundation

public protocol InstanceInitializable {
    
}

extension InstanceInitializable {
    
    public init(instance: Self) {
        self = instance
    }
    
}
