import Foundation

public extension TimeInterval {
    
    public static let minute: TimeInterval = 60
    public static let hour: TimeInterval = 60 * .minute
    public static let day: TimeInterval = 24 * .hour
    public static let week: TimeInterval = 7 * .day
    public static let month: TimeInterval = 30 * .day
    
}
