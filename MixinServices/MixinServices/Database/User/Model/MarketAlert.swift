import Foundation
import GRDB

public struct MarketAlert {
    
    public let alertID: String
    public let assetID: String
    public let type: AlertType
    public let frequency: AlertFrequency
    public var status: Status
    public let value: String
    public let createdAt: String
    
    public func replacing(type: AlertType, frequency: AlertFrequency, value: String) -> MarketAlert {
        MarketAlert(
            alertID: alertID,
            assetID: assetID,
            type: type,
            frequency: frequency,
            status: status,
            value: value,
            createdAt: createdAt
        )
    }
    
}

extension MarketAlert {
    
    public enum AlertType: String, CaseIterable, Codable {
        case priceReached = "price_reached"
        case priceIncreased = "price_increased"
        case priceDecreased = "price_decreased"
        case percentageIncreased = "percentage_increased"
        case percentageDecreased = "percentage_decreased"
    }
    
    public enum AlertFrequency: String, CaseIterable, Codable {
        case every
        case daily
        case once
    }
    
    public enum Status: String, Codable {
        case running
        case paused
    }
    
}

extension MarketAlert: Codable, PersistableRecord {
    
    enum CodingKeys: String, CodingKey {
        case alertID = "alert_id"
        case assetID = "asset_id"
        case type = "type"
        case frequency = "frequency"
        case status = "status"
        case value = "value"
        case createdAt = "created_at"
    }
    
}

extension MarketAlert: TableRecord, MixinFetchableRecord {
    
    public static let databaseTableName = "market_alerts"
    
}
