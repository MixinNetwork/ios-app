import Foundation

class Counter {
    
    private(set) var value: Int
    
    init(value: Int) {
        self.value = value
    }
    
    var advancedValue: Int {
        value += 1
        return value
    }
    
}
