import Foundation

internal class Atomic<T> {
    
    private let lock = NSLock()
    private var _value: T
    
    init (_ value: T) {
        _value = value
    }
    
    var value: T {
        get {
            lock.lock()
            let val = _value
            lock.unlock()
            return val
        }
        set {
            lock.lock()
            self._value = newValue
            lock.unlock()
        }
    }
    
}
