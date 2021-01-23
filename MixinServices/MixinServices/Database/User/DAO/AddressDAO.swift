import Foundation
import GRDB

public final class AddressDAO: UserDatabaseDAO {
    
    public static let shared = AddressDAO()
    public static let addressDidChangeNotification = NSNotification.Name("one.mixin.services.AddressDAO.addressDidChange")
    
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
