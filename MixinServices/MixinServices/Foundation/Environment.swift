import Foundation

public let appGroupIdentifier = "group.one.mixin.messenger"
public let callTimeoutInterval: TimeInterval = 60

public var isAppExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}

public let reporter = reporterClass.init()

public var reporterClass = Reporter.self

public var currentDecimalSeparator: String {
    Locale.current.decimalSeparator ?? "."
}

public var globalSignalContext: OpaquePointer {
    return Signal.context
}

public var canProcessMessages: Bool {
    LoginManager.shared.isLoggedIn && AppGroupUserDefaults.isDocumentsMigrated && !AppGroupUserDefaults.User.needsUpgradeInMainApp
}

public let checkStatusInAppExtensionDarwinNotificationName = CFNotificationName(rawValue: "one.mixin.services.darwin.status.check.extension" as CFString)
public let checkStatusInMainAppDarwinNotificationName = CFNotificationName(rawValue: "one.mixin.services.darwin.status.check.app" as CFString)
