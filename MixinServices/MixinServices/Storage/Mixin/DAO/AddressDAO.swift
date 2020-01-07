import Foundation
import WCDBSwift

public final class AddressDAO {
    
    public static let shared = AddressDAO()
    
    public func getAddress(addressId: String) -> Address? {
        return MixinDatabase.shared.getCodable(condition: Address.Properties.addressId == addressId)
    }
    
    public func getAddress(assetId: String, destination: String, tag: String) -> Address? {
        return MixinDatabase.shared.getCodable(condition: Address.Properties.assetId == assetId && Address.Properties.destination == destination && Address.Properties.tag == tag)
    }
    
    public func getAddresses(assetId: String) -> [Address] {
        return MixinDatabase.shared.getCodables(condition: Address.Properties.assetId == assetId, orderBy: [Address.Properties.updatedAt.asOrder(by: .descending)])
    }
    
    public func insertOrUpdateAddress(addresses: [Address]) {
        guard !addresses.isEmpty else {
            return
        }
        MixinDatabase.shared.insertOrReplace(objects: addresses)
        NotificationCenter.default.afterPostOnMain(name: .AddressDidChange)
    }
    
    public func deleteAddress(assetId: String, addressId: String) {
        MixinDatabase.shared.delete(table: Address.tableName, condition: Address.Properties.addressId == addressId)
        NotificationCenter.default.postOnMain(name: .AddressDidChange)
    }
    
}
