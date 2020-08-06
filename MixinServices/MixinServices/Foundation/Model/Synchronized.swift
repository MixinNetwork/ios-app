import Foundation

@propertyWrapper
public class Synchronized<Value> {
    
    private let lock = NSLock()
    
    private var _value: Value
    
    public init(value: Value) {
        _value = value
    }
    
    public var wrappedValue: Value {
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
