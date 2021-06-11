import Foundation

public class Queue: InstanceInitializable {
    
    public static let main: Queue = MainQueue()
    
    public var dispatchQueue: DispatchQueue {
        fatalError()
    }
    
    public var isCurrent: Bool {
        fatalError()
    }
    
    public convenience init(
        label: String,
        qos: DispatchQoS = .unspecified,
        attributes: DispatchQueue.Attributes = [],
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
        target: DispatchQueue? = nil
    ) {
        let instance = BackgroundQueue(label: label,
                                       qos: qos,
                                       attributes: attributes,
                                       autoreleaseFrequency: autoreleaseFrequency,
                                       target: target)
        self.init(instance: instance as! Self)
    }
    
}

extension Queue {
    
    @inlinable
    public func sync<T>(execute work: () throws -> T) rethrows -> T {
        try dispatchQueue.sync(execute: work)
    }
    
    public func autoSync<T>(execute work: () throws -> T) rethrows -> T {
        if isCurrent {
            return try work()
        } else {
            return try dispatchQueue.sync(execute: work)
        }
    }
    
}

extension Queue {
    
    @inlinable
    public func async(
        group: DispatchGroup? = nil,
        qos: DispatchQoS = .unspecified,
        flags: DispatchWorkItemFlags = [],
        execute work: @escaping @convention(block) () -> Void
    ) {
        dispatchQueue.async(group: group, qos: qos, flags: flags, execute: work)
    }
    
    public func autoAsync(
        group: DispatchGroup? = nil,
        qos: DispatchQoS = .unspecified,
        flags: DispatchWorkItemFlags = [],
        execute work: @escaping @convention(block) () -> Void
    ) {
        if isCurrent {
            work()
        } else {
            dispatchQueue.async(group: group, qos: qos, flags: flags, execute: work)
        }
    }
    
    @inlinable
    public func asyncAfter(
        deadline: DispatchTime,
        qos: DispatchQoS = .unspecified,
        flags: DispatchWorkItemFlags = [],
        execute work: @escaping @convention(block) () -> Void
    ) {
        dispatchQueue.asyncAfter(deadline: deadline, qos: qos, flags: flags, execute: work)
    }
    
    @inlinable
    public func asyncAfter(deadline: DispatchTime, execute: DispatchWorkItem) {
        dispatchQueue.asyncAfter(deadline: deadline, execute: execute)
    }
    
}

fileprivate final class MainQueue: Queue {
    
    override var dispatchQueue: DispatchQueue {
        .main
    }
    
    override var isCurrent: Bool {
        Thread.isMainThread
    }
    
}

fileprivate final class BackgroundQueue: Queue {
    
    private static let specificKey = DispatchSpecificKey<NSObject>()
    
    override var dispatchQueue: DispatchQueue {
        _dispatchQueue
    }
    
    override var isCurrent: Bool {
        DispatchQueue.getSpecific(key: Self.specificKey) === self.specificValue
    }
    
    private let _dispatchQueue: DispatchQueue
    private let specificValue = NSObject()
    
    public init(
        label: String,
        qos: DispatchQoS = .unspecified,
        attributes: DispatchQueue.Attributes = [],
        autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit,
        target: DispatchQueue? = nil
    ) {
        _dispatchQueue = DispatchQueue(label: label,
                                       qos: qos,
                                       attributes: attributes,
                                       autoreleaseFrequency: autoreleaseFrequency,
                                       target: target)
        _dispatchQueue.setSpecific(key: Self.specificKey,
                                   value: specificValue)
    }
    
}
