import Foundation

public extension DateFormatter {
    
    static let filename = DateFormatter(dateFormat: "yyyy-MM-dd_HH:mm:ss")
    
    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
    }
    
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter(dateFormat: "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ")
        formatter.locale = .enUSPOSIX
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
}
