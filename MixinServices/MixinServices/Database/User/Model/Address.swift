import Foundation
import GRDB

public class Address: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case addressId = "address_id"
        case assetId = "asset_id"
        case destination
        case label
        case tag
        case fee
        case dust
        case updatedAt = "updated_at"
    }
    
    public let type: String
    public let addressId: String
    public let assetId: String
    public let destination: String
    public let label: String
    public let tag: String
    public let fee: String
    public let dust: String
    public let updatedAt: String
    
    public private(set) lazy var decimalDust = Decimal(string: dust, locale: .enUSPOSIX) ?? 0
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        addressId = try container.decode(String.self, forKey: .addressId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        assetId = try container.decodeIfPresent(String.self, forKey: .assetId) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        fee = try container.decodeIfPresent(String.self, forKey: .fee) ?? ""
        dust = try container.decodeIfPresent(String.self, forKey: .dust) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
    
}

extension Address: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "addresses"
    
}

extension Address {
    
    public static func fullRepresentation(destination: String, tag: String) -> String {
        tag.isEmpty ? destination : "\(destination):\(tag)"
    }
    
    public static func compactRepresentation(of string: String) -> String {
        truncatedRepresentation(string: string, prefixCount: 8, suffixCount: 6)
    }
    
    public static func truncatedRepresentation(string: String, prefixCount: Int, suffixCount: Int) -> String {
        if string.count > prefixCount + suffixCount {
            string.prefix(prefixCount) + "…" + string.suffix(suffixCount)
        } else {
            string
        }
    }
    
}
