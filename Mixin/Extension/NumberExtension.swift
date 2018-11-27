import Foundation

extension NumberFormatter {
    
    static let decimal = NumberFormatter(numberStyle: .decimal)
    
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

}

extension Int64 {

    func sizeRepresentation() -> String {
        let sizeInBytes = self
        if sizeInBytes < 1024 {
            return "\(sizeInBytes) Bytes"
        } else {
            let sizeInKB = sizeInBytes / 1024
            if sizeInKB <= 1024 {
                return "\(sizeInKB) KB"
            } else {
                return "\(sizeInKB / 1024) MB"
            }
        }
    }

}
