import Foundation
import GRDB

public final class Address: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case feeAssetId = "fee_asset_id"
        case fee
        case reserve
        case dust
        case updatedAt = "updated_at"
    }
    
    public let type: String
    public let addressId: String
    public let assetId: String
    public let destination: String
    public let label: String
    public let tag: String
    public let feeAssetId: String
    public let fee: String
    public let reserve: String
    public let dust: String
    public let updatedAt: String
    
    public private(set) lazy var decimalDust = Decimal(string: dust, locale: .enUSPOSIX) ?? 0
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addressId = try container.decode(String.self, forKey: .addressId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        assetId = try container.decodeIfPresent(String.self, forKey: .assetId) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        feeAssetId = try container.decodeIfPresent(String.self, forKey: .feeAssetId) ?? ""
        fee = try container.decodeIfPresent(String.self, forKey: .fee) ?? ""
        reserve = try container.decodeIfPresent(String.self, forKey: .reserve) ?? ""
        dust = try container.decodeIfPresent(String.self, forKey: .dust) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
    
}

extension Address: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "addresses"
    
}

extension Address {
    
    public var fullAddress: String {
        tag.isEmpty ? destination : "\(destination):\(tag)"
    }
    
    public var compactRepresentation: String {
        let address = self.fullAddress
        if address.count > 10 {
            return address.prefix(6) + "..." + address.suffix(4)
        } else {
            return address
        }
    }
    
}
