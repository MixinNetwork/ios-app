import Foundation

public class SafeDictionary<Key, Value> where Key : Hashable {
    
    private let queue = DispatchQueue(label: "one.mixin.services.dictionary", attributes: .concurrent)
    private var dictionary = [Key: Value]()
    
    public var keys: [Key] {
        var result = [Key]()
        queue.sync {
            result = [Key](self.dictionary.keys)
        }
        return result
    }
    
    public var values: [Value] {
        var result = [Value]()
        queue.sync {
            result = [Value](self.dictionary.values)
        }
        return result
    }
    
    public var count: Int {
        var result = 0
        queue.sync {
            result = self.dictionary.count
        }
        return result
    }
    
    public init() {
        
    }
    
    public func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary.removeValue(forKey: key)
        }
    }
    
    public func removeAll() {
        queue.async(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            var result: Value?
            queue.sync {
                result = self.dictionary[key]
            }
            return result
        }
        set {
            guard let value = newValue else {
                return
            }
            queue.async(flags: .barrier) {
                self.dictionary[key] = value
            }
        }
    }
    
}
