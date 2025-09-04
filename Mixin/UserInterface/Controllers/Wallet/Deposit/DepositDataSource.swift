import Foundation
import MixinServices

class DepositDataSource {
    
    protocol Delegate: AnyObject {
        func depositDataSource(_ dataSource: DepositDataSource, didUpdateViewModel viewModel: DepositViewModel, hint: WalletHintViewController?)
        func depositDataSource(_ dataSource: DepositDataSource, reportsDepositSuspendedWith suspendedView: DepositSuspendedView)
        func depositDataSource(_ dataSource: DepositDataSource, requestNetworkConfirmationWith selector: DepositNetworkSelectorViewController)
    }
    
    let tokenName: String
    let wallet: Wallet
    
    weak var delegate: Delegate?
    
    init(tokenName: String, wallet: Wallet) {
        self.tokenName = tokenName
        self.wallet = wallet
    }
    
    func reload() {
        
    }
    
    func cancel() {
        
    }
    
}

final class MixinDepositDataSource: DepositDataSource {
    
    private let assetID: String
    
    private var token: MixinTokenItem?
    private var task: Task<Void, Error>?
    
    init(assetID: String, tokenName: String) {
        self.assetID = assetID
        self.token = nil
        super.init(tokenName: tokenName, wallet: .privacy)
    }
    
    init(token: MixinTokenItem) {
        self.assetID = token.assetID
        self.token = token
        super.init(tokenName: token.name, wallet: .privacy)
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
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.main.async {
                    let selector = DepositNetworkSelectorViewController(token: token, chain: chain)
                    selector.onDismiss = {
                        continuation.resume(with: .success(()))
                    }
                    if let delegate {
                        delegate.depositDataSource(self, requestNetworkConfirmationWith: selector)
                    } else {
                        continuation.resume(throwing: CancellationError())
                    }
                }
            }
            
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
    
    private static func withAutoRetrying<Result>(
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

final class Web3DepositDataSource: DepositDataSource {
    
    private let token: Web3TokenItem
    
    init(wallet: Web3Wallet, token: Web3TokenItem) {
        self.token = token
        super.init(tokenName: token.name, wallet: .common(wallet))
    }
    
    override func reload() {
        DispatchQueue.global().async { [weak delegate, token] in
            let address = Web3AddressDAO.shared.address(
                walletID: token.walletID,
                chainID: token.chainID
            )
            guard let address else {
                return
            }
            let viewModel = DepositViewModel(
                token: token,
                destination: address.destination,
                tag: nil
            )
            DispatchQueue.main.async {
                delegate?.depositDataSource(self, didUpdateViewModel: viewModel, hint: nil)
            }
        }
    }
    
}
