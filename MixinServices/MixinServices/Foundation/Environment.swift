import Foundation

public let appGroupIdentifier = "group.one.mixin.messenger"

public var isAppExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}

public let reporter = reporterClass.init()

public var reporterClass = Reporter.self

public var currentDecimalSeparator: String {
    Locale.current.decimalSeparator ?? "."
}

public var requestTimeout: TimeInterval = isAppExtension ? 3 : 5

public var globalSignalContext: OpaquePointer {
    return Signal.context
}

public var canProcessMessages: Bool {
    LoginManager.shared.isLoggedIn
        && AppGroupUserDefaults.isDocumentsMigrated
        && !AppGroupUserDefaults.User.needsUpgradeInMainApp
        && !AppGroupUserDefaults.isClockSkewed
        && AppGroupUserDefaults.Crypto.isPrekeyLoaded
        && AppGroupUserDefaults.Crypto.isSessionSynchronized
        && !LoginManager.shared.loggedOutInDeviceTransfer
}

public let checkStatusInAppExtensionDarwinNotificationName = CFNotificationName(rawValue: "one.mixin.messenger.darwin.status.check.extension" as CFString)
public let conversationDidChangeInMainAppDarwinNotificationName = CFNotificationName(rawValue: "one.mixin.messenger.darwin.conversation.did.change" as CFString)

public enum Mention {
    
    public static let prefix: Character = "@"
    public static let suffix: Character = " "
    
}

public func imageWithRatioMaybeAnArticle(_ ratio: CGSize) -> Bool {
    ratio.height / ratio.width > 3
}
