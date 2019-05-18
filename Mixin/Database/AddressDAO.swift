import Foundation
import WCDBSwift

final class AddressDAO {
    
    static let shared = AddressDAO()
    
    func getAddress(addressId: String) -> Address? {
        return MixinDatabase.shared.getCodable(condition: Address.Properties.addressId == addressId, inTransaction: false)
    }

    func getAddress(assetId: String, publicKey: String) -> Address? {
        return MixinDatabase.shared.getCodable(condition: Address.Properties.assetId == assetId && Address.Properties.publicKey == publicKey, inTransaction: false)
    }

    func getAddress(assetId: String, accountName: String, accountTag: String) -> Address? {
        return MixinDatabase.shared.getCodable(condition: Address.Properties.assetId == assetId && Address.Properties.accountTag == accountTag && Address.Properties.accountName == accountName, inTransaction: false)
    }

    func getLastUseAddress(assetId: String) -> Address? {
        if let addressId = WalletUserDefault.shared.lastWithdrawalAddress[assetId], let address = getAddress(addressId: addressId) {
            return address
        }
        return MixinDatabase.shared.getCodables(condition: Address.Properties.assetId == assetId, orderBy: [Address.Properties.updatedAt.asOrder(by: .descending)], limit: 1, inTransaction: false).first
    }
    
    func getAddresses(assetId: String) -> [Address] {
        return MixinDatabase.shared.getCodables(condition: Address.Properties.assetId == assetId, orderBy: [Address.Properties.updatedAt.asOrder(by: .descending)], inTransaction: false)
    }
    
    func insertOrUpdateAddress(addresses: [Address]) {
        guard !addresses.isEmpty else {
            return
        }
        MixinDatabase.shared.insertOrReplace(objects: addresses)
        NotificationCenter.default.afterPostOnMain(name: .AddressDidChange)
    }

    func deleteAddress(assetId: String, addressId: String) {
        MixinDatabase.shared.delete(table: Address.tableName, condition: Address.Properties.addressId == addressId)
        NotificationCenter.default.postOnMain(name: .AddressDidChange)

        if WalletUserDefault.shared.lastWithdrawalAddress[assetId] == addressId {
            WalletUserDefault.shared.lastWithdrawalAddress[assetId] = nil
        }
    }
}
