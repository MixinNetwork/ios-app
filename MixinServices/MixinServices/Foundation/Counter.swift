import Foundation

public class Counter {
    
    public private(set) var value: Int
    
    public var advancedValue: Int {
        value += 1
        return value
    }
    
    public init(value: Int) {
        self.value = value
    }
    
}
