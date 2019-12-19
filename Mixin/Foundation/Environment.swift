import Foundation

public let appGroupIdentifier = "group.one.mixin.messenger"
public let callTimeoutInterval: TimeInterval = 60

public var isAppExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}
