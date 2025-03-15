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
        
    """
    
    public func getAddress(addressId: String) -> Address? {
        db.select(where: Address.column(of: .addressId) == addressId)
    }
    
    public func getAddress(chainId: String, destination: String, tag: String) -> Address? {
        let condition: SQLSpecificExpressible = Address.column(of: .chainId) == chainId
            && Address.column(of: .destination) == destination
            && Address.column(of: .tag) == tag
        return db.select(where: condition)
    }
    
    public func getAddresses(chainId: String) -> [Address] {
        db.select(where: Address.column(of: .chainId) == chainId,
                  order: [Address.column(of: .updatedAt).desc])
    }
    
    public func addressItem(id: String) -> AddressItem? {
        db.select(with: addressItemSQL + "WHERE a.address_id = ?\nORDER BY a.updated_at DESC", arguments: [id])
    }
    
    public func addressItems() -> [AddressItem] {
        db.select(with: addressItemSQL + "ORDER BY a.updated_at DESC")
    }
    
    public func label(address: String) -> String? {
        db.select(column: Address.column(of: .label),
                  from: Address.self,
                  where: Address.column(of: .destination) == address)
    }
    
    public func insertOrUpdateAddress(addresses: [Address]) {
        guard !addresses.isEmpty else {
            return
        }
        db.save(addresses) { _ in
            NotificationCenter.default.post(onMainThread: Self.addressDidChangeNotification, object: self)
        }
    }
    
    public func deleteAddress(addressId: String) {
        db.delete(Address.self, where: Address.column(of: .addressId) == addressId) { _ in
            NotificationCenter.default.post(onMainThread: Self.addressDidChangeNotification, object: self)
        }
    }
    
}
