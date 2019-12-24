import Foundation

public extension NumberFormatter {
    
    static let decimal = NumberFormatter(numberStyle: .decimal)
    
    static let simplePercentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimum = 0.01
        formatter.maximum = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .floor
        formatter.locale = .current
        return formatter
    }()

    static let simpleFileSize: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .halfUp
        return formatter
    }()
    
    convenience init(numberStyle: NumberFormatter.Style, maximumFractionDigits: Int? = nil, roundingMode: NumberFormatter.RoundingMode? = nil, locale: Locale? = nil) {
        self.init()
        self.numberStyle = numberStyle
        if let maximumFractionDigits = maximumFractionDigits {
            self.maximumFractionDigits = maximumFractionDigits
        }
        if let roundingMode = roundingMode {
            self.roundingMode = roundingMode
        }
        if let locale = locale {
            self.locale = locale
        }
    }

    func stringFormat(value: Float64) -> String {
        return string(from: NSNumber(value: value)) ?? "\(Int64(value))"
    }
}

public extension Int64 {

    func sizeRepresentation() -> String {
        let sizeInBytes = self
        if sizeInBytes < 1024 {
            return "\(sizeInBytes) Bytes"
        } else {
            let sizeInKB = Float64(sizeInBytes) / Float64(1024)
            if sizeInKB <= 1024 {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB)) KB"
            } else if sizeInKB > 1024 * 1024  {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB / Float64(1024 * 1024))) GB"
            } else {
                return "\(NumberFormatter.simpleFileSize.stringFormat(value: sizeInKB / Float64(1024))) MB"
            }
        }
    }

}
