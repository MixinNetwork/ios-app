import Foundation

public enum PriceHistoryPeriod: String, CaseIterable, Equatable, Codable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case ytd = "YTD"
    case all = "ALL"
}
