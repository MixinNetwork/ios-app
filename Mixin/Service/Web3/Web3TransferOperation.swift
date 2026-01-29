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
        case noFeeToken(String)
    }
    
    enum SimulationDisplay {
        
        case byLocal(TransactionSimulation)
        
        // Can't decode tx locally, typically when signing external tx
        case byRemote
        
        // Hide the simulation row, like when speed up / cancelling another tx
        case hidden
        
    }
    
    let wallet: Web3Wallet
    let fromAddress: Web3Address
    let toAddress: String? // Always the receiver, not the contract address
    let chain: Web3Chain
    let feeToken: Web3TokenItem
    let isResendingTransactionAvailable: Bool
    let simulationDisplay: SimulationDisplay
    let isFeeWaived: Bool
    
    @MainActor @Published
    var state: State = .loading
    
    @MainActor
    var fee: Web3DisplayFee?
    
    var hasTransactionSent = false
    
    init(
        wallet: Web3Wallet, fromAddress: Web3Address, toAddress: String?,
        chain: Web3Chain, feeToken: Web3TokenItem,
        isResendingTransactionAvailable: Bool,
        simulationDisplay: SimulationDisplay, isFeeWaived: Bool
    ) {
        self.wallet = wallet
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.chain = chain
        self.feeToken = feeToken
        self.isResendingTransactionAvailable = isResendingTransactionAvailable
        self.simulationDisplay = simulationDisplay
        self.isFeeWaived = isFeeWaived
    }
    
    func loadFee() async throws -> Web3DisplayFee {
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
