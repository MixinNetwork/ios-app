import Foundation
import MixinServices

struct AddressBookNetwork {
    
    let chainID: String
    let name: String
    let chain: Chain?
    
}

extension AddressBookNetwork {
    
    private static let pinned: [(chainID: String, name: String)] = [
        (ChainID.bitcoin, "Bitcoin"),
        (ChainID.lightning, "Lightning Network"),
        (ChainID.ethereum, "Ethereum"),
        (ChainID.solana, "Solana"),
        (ChainID.litecoin, "Litecoin"),
        (ChainID.bnbSmartChain, "BNB Smart Chain"),
        (ChainID.ripple, "Ripple"),
        (ChainID.tron, "TRON"),
        (ChainID.dogecoin, "Dogecoin"),
    ]
    
    // Pinned networks keep the design order, the remaining chains follow by name.
    // Pass nil `supportedChainIDs` to include networks of all chains.
    static func all(
        chains: [String: Chain],
        supportedChainIDs: Set<String>?,
    ) -> [AddressBookNetwork] {
        let pinnedChainIDs = Set(pinned.map(\.chainID))
        let pinnedNetworks = pinned.map { item in
            AddressBookNetwork(
                chainID: item.chainID,
                name: item.name,
                chain: chains[item.chainID]
            )
        }
        let cachedNetworks = chains.values
            .filter { !pinnedChainIDs.contains($0.chainId) }
            .map { AddressBookNetwork(chainID: $0.chainId, name: $0.name, chain: $0) }
        let uncachedNetworks = Web3Chain.all
            .filter {
                supportedChainIDs?.contains($0.chainID) == true
                && !pinnedChainIDs.contains($0.chainID)
                && chains[$0.chainID] == nil
            }
            .map { AddressBookNetwork(chainID: $0.chainID, name: $0.name, chain: nil) }
        let otherNetworks = (cachedNetworks + uncachedNetworks)
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        let networks = pinnedNetworks + otherNetworks
        if let supportedChainIDs {
            return networks.filter { supportedChainIDs.contains($0.chainID) }
        } else {
            return networks
        }
    }
    
    static func currentWalletChainIDs() -> Set<String>? {
        switch AppGroupUserDefaults.Wallet.lastSelectedWallet {
        case let .common(id):
            let allChainIDs = Set(Web3Chain.all.map(\.chainID))
            let wallet = Web3WalletDAO.shared.wallet(id: id)
            switch wallet?.category.knownCase {
            case .classic, .importedMnemonic:
                return allChainIDs
            case .importedPrivateKey, .watchAddress, .none:
                // Each address identifies its chain family, e.g. an EVM address works on all EVM chains.
                // Keep the address chains as well, some of them are not in `Web3Chain`,
                // e.g. Litecoin addresses imported on Android.
                let addressChainIDs = Web3AddressDAO.shared.chainIDs(walletID: id)
                let familyChainIDs = addressChainIDs
                    .compactMap { Web3Chain.chain(chainID: $0) }
                    .flatMap { $0.kind.chains.map(\.chainID) }
                let chainIDs = addressChainIDs.union(familyChainIDs)
                return chainIDs.isEmpty ? allChainIDs : chainIDs
            }
        case .privacy, .safe:
            return nil
        }
    }
    
    static func name(chainID: String, chain: Chain?) -> String {
        pinned.first { $0.chainID == chainID }?.name ?? chain?.name ?? ""
    }
    
    // All networks: Ethereum. Otherwise the first selected one in display order.
    // Falls back to the first network when Ethereum is not supported.
    static func defaultNetwork(
        selectedChainIDs: Set<String>,
        networks: [AddressBookNetwork]
    ) -> AddressBookNetwork? {
        networks.first { selectedChainIDs.contains($0.chainID) }
            ?? networks.first { $0.chainID == ChainID.ethereum }
            ?? networks.first
    }
    
}
