import UIKit
import MixinServices

final class UnlockSolanaAccountViewController: UnlockWeb3AccountViewController {
    
    init() {
        super.init(category: .solana)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func deriveAddress(pin: String) async throws -> String {
        let spendKey = try await TIP.spendPriv(pin: pin)
        let privateKey = try TIP.deriveSolanaPrivateKey(spendKey: spendKey)
        let address = try Solana.publicKey(seed: privateKey)
        let redundantAddress = try TIP.solanaAddress(spendKey: spendKey)
        guard address == redundantAddress else {
            Logger.web3.error(category: "Unlock", message: "Address: \(address), RA: \(redundantAddress)")
            throw GenerationError.mismatched
        }
        PropertiesDAO.shared.set(address, forKey: .solanaAddress)
        Logger.web3.info(category: "Unlock", message: "Solana unlocked")
        return address
    }
    
}
