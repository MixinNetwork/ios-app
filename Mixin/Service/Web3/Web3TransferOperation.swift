import Foundation
import MixinServices

class Web3TransferOperation {
    
    enum State {
        case loading
        case unavailable(reason: String)
        case ready
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    enum SigningError: Error {
        case invalidTransaction
        case invalidBlockhash
        case noFeeLoaded
        case noFeeToken(String)
        case gaslessChainMismatch
        case gaslessPayloadMismatch
        case invalidEIP7702AuthAddress
        case invalidUserOperation
        case invalidEIP7702AuthMessage
    }
    
    enum SimulationDisplay {
        
        case byLocal(TransactionSimulation)
        
        // Can't decode tx locally, typically when signing external tx
        case byRemote
        
        // Hide the simulation row, like when speed up / cancelling another tx
        case hidden
        
    }
    
    enum FeePolicy {
        
        // Provides several gasless fees for user to pick
        // fallback to native if network failure
        case prefersGasless
        
        // Use same token for transferring and gasless fee
        // fallback to native if balance insufficient, or network failure
        case prefersGaslessInKind
        
        case alwaysNative
        
    }
    
    enum FeeLoadingError: Error {
        case gaslessUnavailable
        case gaslessInKindInsufficient
    }
    
    struct Fee {
        
        let options: [Web3DisplayFee]
        
        var selectedIndex: Int
        
        var selected: Web3DisplayFee {
            options[selectedIndex]
        }
        
        static func native(token: Web3TokenItem, amount: Decimal) -> Fee {
            let option = Web3DisplayFee(token: token, amount: amount, gasless: false)
            return Fee(options: [option], selectedIndex: 0)
        }
        
    }
    
    let wallet: Web3Wallet
    let fromAddress: Web3Address
    let toAddress: String? // Always the receiver, not the contract address
    let chain: Web3Chain
    let nativeFeeToken: Web3TokenItem
    let simulationDisplay: SimulationDisplay
    let isFeeWaived: Bool
    
    @MainActor @Published
    var state: State = .loading
    
    @MainActor
    var fee: Fee?
    
    var hasTransactionSent = false
    
    @MainActor
    var isResendingTransactionAvailable: Bool {
        false
    }
    
    init(
        wallet: Web3Wallet, fromAddress: Web3Address, toAddress: String?,
        chain: Web3Chain, feeToken: Web3TokenItem,
        simulationDisplay: SimulationDisplay, isFeeWaived: Bool
    ) {
        self.wallet = wallet
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.nativeFeeToken = feeToken
        self.simulationDisplay = simulationDisplay
        self.isFeeWaived = isFeeWaived
    }
    
    func reloadFee() async throws -> Fee {
        fatalError("Must override")
    }
    
    func simulateTransaction() async throws -> TransactionSimulation {
        switch simulationDisplay {
        case .byLocal(let simulation):
            return simulation
        case .byRemote:
            fatalError("Override to request a simulation")
        case .hidden:
            fatalError("Check value for `hidden` before calling this")
        }
    }
    
    func start(pin: String) async throws {
        assertionFailure("Must override")
    }
    
    func reject() {
        assertionFailure("Must override")
    }
    
    func rejectTransactionIfNotSent() {
        guard !hasTransactionSent else {
            return
        }
        Logger.web3.info(category: "Web3Transfer", message: "Rejected by dismissing")
        reject()
    }
    
    @MainActor func resendTransaction() {
        
    }
    
}

extension Web3TransferOperation {
    
    static func tokens(
        walletID: String,
        assetIDs: [String]
    ) async throws -> [String: Web3TokenItem] {
        var tokens = Web3TokenDAO.shared.tokenItems(
            walletID: walletID,
            ids: assetIDs
        ).reduce(into: [:]) { result, token in
            result[token.assetID] = token
        }
        // TODO: Get more tokens from remote
        return tokens
    }
    
    func tokenAmountFormat(precision: Int16) -> Decimal.FormatStyle {
        Decimal.FormatStyle.number
            .locale(.enUSPOSIX)
            .grouping(.never)
            .sign(strategy: .never)
            .precision(.fractionLength(0...Int(precision)))
    }
    
}
