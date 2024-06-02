import UIKit
import web3
import MixinServices

final class UnlockEVMAccountViewController: UnlockWeb3AccountViewController {
    
    init() {
        super.init(category: .evm)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func deriveAddress(pin: String) async throws -> String {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let address = try {
            let priv = try TIP.deriveEthereumPrivateKey(spendKey: spendKey)
            let keyStorage = InPlaceKeyStorage(raw: priv)
            let account = try EthereumAccount(keyStorage: keyStorage)
            return account.address.toChecksumAddress()
        }()
        let redundantAddress = try TIP.evmAddress(spendKey: spendKey)
        guard address == redundantAddress else {
            Logger.web3.error(category: "Unlock", message: "Address: \(address), RA: \(redundantAddress)")
            throw GenerationError.mismatched
        }
        PropertiesDAO.shared.set(address, forKey: .evmAddress)
        Logger.web3.info(category: "Unlock", message: "EVM unlocked")
        return address
    }
    
}
