import Foundation
import GRDB

public struct Address {
    
    public let type: String
    public let addressId: String
    public let assetId: String
    public let destination: String
    public let label: String
    public let tag: String
    public let fee: String
    public let reserve: String
    public let dust: String
    public let updatedAt: String
    
}

extension Address: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case fee
        case reserve
        case dust
        case updatedAt = "updated_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addressId = try container.decode(String.self, forKey: .addressId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        assetId = try container.decodeIfPresent(String.self, forKey: .assetId) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
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
    
}
