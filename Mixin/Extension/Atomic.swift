import Foundation

class Atomic<T> {

    private let queue = DispatchQueue(label: "one.mixin.messager.atomic", attributes: .concurrent)
    private var _value: T

    init (_ value: T) {
        _value = value
    }

    var value: T {
        get {
            return queue.sync { self._value }
        }
        set {
            queue.async(flags: .barrier) {
                self._value = newValue
            }
        }
    }
}
