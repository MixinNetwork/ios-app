import Foundation

public extension Locale {
    
    static let us = Locale(identifier: "US")
    
    // https://developer.apple.com/library/archive/qa/qa1480/_index.html
    // In most cases the best locale to choose is "en_US_POSIX", a locale that's specifically designed to yield US English results regardless of both user and system preferences. "en_US_POSIX" is also invariant in time (if the US, at some point in the future, changes the way it formats dates, "en_US" will change to reflect the new behaviour, but "en_US_POSIX" will not), and between machines ("en_US_POSIX" works the same on iOS as it does on OS X, and as it it does on other platforms).
    static let enUSPOSIX = Locale(identifier: "en_US_POSIX")
    
}
