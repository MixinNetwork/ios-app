import Foundation

public let appGroupIdentifier = "group.one.mixin.messenger"

public var isAppExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}
