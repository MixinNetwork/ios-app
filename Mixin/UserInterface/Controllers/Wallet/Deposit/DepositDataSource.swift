import Foundation
import MixinServices

class DepositDataSource {
    
    protocol Delegate: AnyObject {
        func depositDataSource(_ dataSource: DepositDataSource, didUpdateViewModel viewModel: DepositViewModel, hint: WalletHintViewController?)
        func depositDataSource(_ dataSource: DepositDataSource, reportsDepositSuspendedWith suspendedView: DepositSuspendedView)
    }
    
    let wallet: Wallet
    let assetID: String
    let symbol: String
    
    weak var delegate: Delegate?
    
    fileprivate init(wallet: Wallet, assetID: String, symbol: String) {
        self.wallet = wallet
        self.assetID = assetID
        self.symbol = symbol
    }
    
    func reload() {
        
    }
    
    func cancel() {
        
    }
    
    func dataSource(bySwitchingTo token: DepositViewModel.SwitchableToken) -> DepositDataSource {
        switch wallet {
        case .privacy:
            MixinDepositDataSource(assetID: token.assetID, symbol: token.symbol)
        case .common(let wallet):
            Web3DepositDataSource(wallet: wallet, assetID: token.assetID, symbol: token.symbol)
        case .safe:
            fatalError("Never deposit to safe wallets")
        }
    }
    
    fileprivate static func withAutoRetrying<Result>(
        interval: TimeInterval = 3,
        execute block: () async throws -> Result
    ) async throws -> Result {
        repeat {
            try Task.checkCancellation()
            do {
                return try await block()
            } catch {
                switch error {
                case MixinAPIResponseError.unauthorized, MixinAPIResponseError.addressGenerating:
                    throw error
                default:
                    try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                }
            }
        } while LoginManager.shared.isLoggedIn
        throw MixinAPIResponseError.unauthorized
    }
    
}

final class MixinDepositDataSource: DepositDataSource {
    
    private var token: MixinTokenItem?
    private var task: Task<Void, Error>?
    
    init(assetID: String, symbol: String) {
        self.token = nil
        super.init(wallet: .privacy, assetID: assetID, symbol: symbol)
    }
    
    init(token: MixinTokenItem) {
        self.token = token
        super.init(wallet: .privacy, assetID: token.assetID, symbol: token.symbol)
    }
    
    override func reload() {
        task = Task.detached { [weak delegate, assetID, preloadedToken=token] in
            var token: MixinTokenItem
            if let preloadedToken {
                token = preloadedToken
            } else if let localToken = TokenDAO.shared.tokenItem(assetID: assetID) {
                token = localToken
            } else {
                let remoteToken = try await Self.withAutoRetrying {
                    try await SafeAPI.assets(id: assetID)
                }
                TokenDAO.shared.save(assets: [remoteToken])
                token = MixinTokenItem(token: remoteToken, balance: "0", isHidden: false, chain: nil)
                try Task.checkCancellation()
            }
            
            let chain: Chain
            if let tokenChain = token.chain {
                chain = tokenChain
            } else if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                chain = localChain
            } else {
                chain = try await Self.withAutoRetrying {
                    try await NetworkAPI.chain(id: token.chainID)
                }
                ChainDAO.shared.save([chain])
                Web3ChainDAO.shared.save([chain])
                try Task.checkCancellation()
            }
            if token.chain == nil {
                token = MixinTokenItem(
                    token: token,
                    balance: token.balance,
                    isHidden: token.isHidden,
                    chain: chain
                )
            }
            
            let localEntry = DepositEntryDAO.shared.primaryEntry(ofChainWith: chain.chainId)
            try Task.checkCancellation()
            if let localEntry {
                let viewModel = DepositViewModel(token: token, entry: localEntry)
                try await MainActor.run {
                    try Task.checkCancellation()
                    delegate?.depositDataSource(self, didUpdateViewModel: viewModel, hint: nil)
                }
            }
            
            do {
                let remoteEntries = try await Self.withAutoRetrying {
                    try await SafeAPI.depositEntries(assetID: token.assetID, chainID: chain.chainId)
                }
                DepositEntryDAO.shared.replace(entries: remoteEntries, forChainWith: token.chainID)
                let remoteEntry = remoteEntries.first { entry in
                    entry.isPrimary && entry.chainID == chain.chainId
                }
                if let remoteEntry {
                    let viewModel = DepositViewModel(token: token, entry: remoteEntry)
                    let hasChanged: Bool = if let localEntry {
                        localEntry.destination != remoteEntry.destination
                            || localEntry.tag != remoteEntry.tag
                    } else {
                        false
                    }
                    try await MainActor.run {
                        try Task.checkCancellation()
                        let hint: WalletHintViewController? = if hasChanged {
                            WalletHintViewController(content: .addressUpdated(token))
                        } else {
                            nil
                        }
                        delegate?.depositDataSource(self, didUpdateViewModel: viewModel, hint: hint)
                    }
                }
            } catch MixinAPIResponseError.addressGenerating {
                try await MainActor.run {
                    try Task.checkCancellation()
                    let suspended = R.nib.depositSuspendedView(withOwner: nil)!
                    suspended.symbol = if token.assetID == AssetID.omniUSDT {
                        "OMNI - USDT"
                    } else {
                        token.symbol
                    }
                    suspended.isHidden = false
                    delegate?.depositDataSource(self, reportsDepositSuspendedWith: suspended)
                }
            } catch {
                // Only `addressGenerating` and `unauthorized` could be thrown
                // Do nothing when encountered
            }
        }
    }
    
    override func cancel() {
        task?.cancel()
    }
    
}

final class Web3DepositDataSource: DepositDataSource {
    
    private let walletID: String
    
    private var token: Web3TokenItem?
    
    init(wallet: Web3Wallet, token: Web3TokenItem) {
        self.walletID = wallet.walletID
        self.token = token
        super.init(wallet: .common(wallet), assetID: token.assetID, symbol: token.symbol)
    }
    
    init(wallet: Web3Wallet, assetID: String, symbol: String) {
        self.walletID = wallet.walletID
        self.token = nil
        super.init(wallet: .common(wallet), assetID: assetID, symbol: symbol)
    }
    
    override func reload() {
        Task.detached { [weak delegate, walletID, assetID, preloadedToken=token] in
            var token: Web3TokenItem
            if let preloadedToken {
                token = preloadedToken
            } else if let localToken = Web3TokenDAO.shared.token(walletID: walletID, assetID: assetID) {
                token = localToken
            } else {
                let mixinToken = try await Self.withAutoRetrying {
                    try await SafeAPI.assets(id: assetID)
                }
                token = Web3TokenItem(
                    token: Web3Token(
                        walletID: walletID,
                        assetID: mixinToken.assetID,
                        chainID: mixinToken.chainID,
                        assetKey: mixinToken.assetKey,
                        kernelAssetID: mixinToken.kernelAssetID,
                        symbol: mixinToken.symbol,
                        name: mixinToken.name,
                        precision: mixinToken.precision,
                        iconURL: mixinToken.iconURL,
                        amount: "0",
                        usdPrice: mixinToken.usdPrice,
                        usdChange: mixinToken.usdChange,
                        level: Web3Reputation.Level.unknown.rawValue,
                    ),
                    hidden: false,
                    chain: nil
                )
                try Task.checkCancellation()
            }
            
            let chain: Chain
            if let tokenChain = token.chain {
                chain = tokenChain
            } else if let localChain = Web3ChainDAO.shared.chain(chainID: token.chainID) {
                chain = localChain
            } else {
                chain = try await Self.withAutoRetrying {
                    try await NetworkAPI.chain(id: token.chainID)
                }
                ChainDAO.shared.save([chain])
                Web3ChainDAO.shared.save([chain])
                try Task.checkCancellation()
            }
            if token.chain == nil {
                token = Web3TokenItem(token: token, hidden: token.isHidden, chain: chain)
            }
            
            let address = Web3AddressDAO.shared.address(
                walletID: token.walletID,
                chainID: token.chainID
            )
            let switchableChainIDs = Web3AddressDAO.shared.chainIDs(walletID: token.walletID)
            guard let address else {
                return
            }
            let viewModel = DepositViewModel(
                token: token,
                address: address.destination,
                switchableChainIDs: switchableChainIDs
            )
            DispatchQueue.main.async {
                delegate?.depositDataSource(self, didUpdateViewModel: viewModel, hint: nil)
            }
        }
    }
    
}
