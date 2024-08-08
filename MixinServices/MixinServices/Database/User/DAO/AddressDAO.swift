import Foundation
import GRDB

public final class AddressDAO: UserDatabaseDAO {
    
    public static let shared = AddressDAO()
    public static let addressDidChangeNotification = NSNotification.Name("one.mixin.services.AddressDAO.addressDidChange")
    
    private let addressItemSQL = """
        SELECT a.*, t.icon_url AS token_icon_url, c.icon_url AS token_chain_icon_url
        FROM addresses a
            LEFT JOIN tokens t ON a.asset_id = t.asset_id
            LEFT JOIN chains c ON t.chain_id = c.chain_id
        ORDER BY a.updated_at DESC
    """
    
    public func getAddress(addressId: String) -> Address? {
        db.select(where: Address.column(of: .addressId) == addressId)
    }
    
    public func getAddress(assetId: String, destination: String, tag: String) -> Address? {
        let condition: SQLSpecificExpressible = Address.column(of: .assetId) == assetId
            && Address.column(of: .destination) == destination
            && Address.column(of: .tag) == tag
        return db.select(where: condition)
    }
    
    public func getAddresses(assetId: String) -> [Address] {
        db.select(where: Address.column(of: .assetId) == assetId,
                  order: [Address.column(of: .updatedAt).desc])
    }
    
    public func addressItem(id: String) -> AddressItem? {
        db.select(with: addressItemSQL + "\nWHERE a.address_id = ?", arguments: [id])
    }
    
    public func addressItems() -> [AddressItem] {
        db.select(with: addressItemSQL)
    }
    
    public func insertOrUpdateAddress(addresses: [Address]) {
        guard !addresses.isEmpty else {
            return
        }
        db.save(addresses) { _ in
            NotificationCenter.default.post(onMainThread: Self.addressDidChangeNotification, object: self)
        }
    }
    
    public func deleteAddress(assetId: String, addressId: String) {
        db.delete(Address.self, where: Address.column(of: .addressId) == addressId) { _ in
            NotificationCenter.default.post(onMainThread: Self.addressDidChangeNotification, object: self)
        }
    }
    
}
