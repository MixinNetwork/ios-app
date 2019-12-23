import Foundation

func performSynchronouslyOnMainThread<T>(_ work: (() -> T)) -> T {
    if Thread.isMainThread {
        return work()
    } else {
        return DispatchQueue.main.sync(execute: work)
    }
}
