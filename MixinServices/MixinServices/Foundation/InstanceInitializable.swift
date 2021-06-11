import Foundation

protocol InstanceInitializable {
    
}

extension InstanceInitializable {
    
    init(instance: Self) {
        self = instance
    }
    
}
