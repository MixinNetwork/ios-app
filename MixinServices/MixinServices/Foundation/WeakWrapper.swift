import Foundation

public final class WeakWrapper<Wrapped> {
    
    public private(set) var unwrapped: Wrapped?
    
    public init(object: Wrapped) {
        self.unwrapped = object
    }
    
}
