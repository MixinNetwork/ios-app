import Foundation

public let millisecondsPerSecond: TimeInterval = 1000
public let secondsPerMinute: TimeInterval = 60
public let secondsPerHour: TimeInterval = 60 * secondsPerMinute
public let secondsPerDay: TimeInterval = 24 * secondsPerHour

public let bytesPerKiloByte: UInt = 1024
public let bytesPerMegaByte: UInt = bytesPerKiloByte * 1024

public enum JPEGCompressionQuality {
    public static let max: CGFloat = 1
    public static let high: CGFloat = 0.85
    public static let medium: CGFloat = 0.75
    public static let low: CGFloat = 0.6
}
