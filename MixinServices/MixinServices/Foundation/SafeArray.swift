import Foundation

public class SafeArray<Element> {

    private let queue = DispatchQueue(label: "one.mixin.services.dictionary", attributes: .concurrent)
    private var array = [Element]()

    public init() {

    }

    public func append(_ newElement: Element) {
        queue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }

    public func popFirst() -> Element? {
		var result: Element?
        queue.async(flags: .barrier) {
			if self.array.count > 0 {
				result = self.array.removeFirst()
			}
        }
        return result
    }

    public var first: Element? {
        var result: Element?
        queue.sync {
            result = self.array.first
        }
        return result
    }

    public var count: Int {
        var result = 0
        queue.sync {
            result = self.array.count
        }
        return result
    }

}

public extension SafeArray where Element: Equatable {

    public func contains(_ element: Element) -> Bool {
        var result = false
        queue.sync {
            result = self.array.contains(element)
        }
        return result
    }

    public func remove(element: Element) {
        queue.async(flags: .barrier) {
            self.array = self.array.filter { $0 != element }
        }
   }
}

