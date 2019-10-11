import Foundation

struct WeakBox<T: AnyObject> {
    weak var object: T?
}
