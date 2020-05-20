import Foundation

public class SafeSet<Element> where Element : Hashable {

    private let queue = DispatchQueue(label: "one.mixin.services.set", attributes: .concurrent)
    private var elements = Set<Element>()

    public init() {

    }

    public init(_ arrayLiteral: [Element]) {
        queue.async(flags: .barrier) {
            self.elements = Set<Element>(arrayLiteral)
        }
    }

    public func insert(_ newElement: Element) {
        queue.async(flags: .barrier) {
            self.elements.insert(newElement)
        }
    }

    public func formUnion<S>(_ other: S) where Element == S.Element, S : Sequence {
        queue.async(flags: .barrier) {
            self.elements.formUnion(other)
        }
    }

    public var count: Int {
        var result = 0
        queue.sync {
            result = self.elements.count
        }
        return result
    }

}

public extension SafeSet where Element: Equatable {

    public func contains(_ element: Element) -> Bool {
        var result = false
        queue.sync {
            result = self.elements.contains(element)
        }
        return result
    }

    public func remove(_ element: Element) {
        queue.async(flags: .barrier) {
            self.elements.remove(element)
        }
   }
}

