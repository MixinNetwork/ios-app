import Foundation
import web3
import Web3Wallet
import MixinServices

class Web3SignOperation {
    
    enum State {
        case pending
        case signing
        case signingFailed(Error)
        case sending
        case sendingFailed(Error)
        case success
    }
    
    enum SigningError: Error {
        case mismatchedAddress
    }
    
    let address: String
    let proposer: Web3Proposer
    let humanReadableMessage: String
    
    fileprivate let signable: WalletConnectDecodedSigningRequest.Signable
    
    @Published
    fileprivate(set) var state: State = .pending
    
    fileprivate var signature: String?
    fileprivate var hasSignatureSent = false
    
    fileprivate init(
        address: String,
        proposer: Web3Proposer,
        humanReadableMessage: String,
        signable: WalletConnectDecodedSigningRequest.Signable
    ) {
        self.address = address
        self.proposer = proposer
        self.humanReadableMessage = humanReadableMessage
        self.signable = signable
    }
    
    func start(with pin: String) {
        state = .signing
        Task.detached { [signable] in
            Logger.web3.info(category: "Sign", message: "Will sign")
            let signature: String
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: keyStorage)
                signature = switch signable {
                case .raw(let data):
                    try account.signMessage(message: data)
                case .typed(let data):
                    try account.signMessage(message: data)
                }
            } catch {
                Logger.web3.error(category: "Sign", message: "Failed to sign: \(error)")
                await MainActor.run {
                    self.state = .signingFailed(error)
                }
                return
            }
            Logger.web3.info(category: "Sign", message: "Will send")
            await MainActor.run {
                self.signature = signature
                self.state = .sending
            }
            await self.send(signature: signature)
        }
    }
    
    func reject() {
        assertionFailure("Must override")
    }
    
    func rejectRequestIfSignatureNotSent() {
        guard !hasSignatureSent else {
            return
        }
        Logger.web3.info(category: "Sign", message: "Rejected by dismissing")
        reject()
    }
    
    @objc func resendSignature(_ sender: Any) {
        guard let signature else {
            return
        }
        state = .sending
        Logger.web3.info(category: "Sign", message: "Will resend")
        Task.detached {
            await self.send(signature: signature)
        }
    }
    
    fileprivate func send(signature: String) async {
        assertionFailure("Must override")
    }
    
}

final class Web3SignWithWalletConnectOperation: Web3SignOperation {
    
    let session: WalletConnectSession
    let request: WalletConnectDecodedSigningRequest
    
    init(
        address: String,
        session: WalletConnectSession,
        request: WalletConnectDecodedSigningRequest
    ) {
        self.session = session
        self.request = request
        let proposer = Web3Proposer(name: session.name, host: session.host)
        super.init(address: address,
                   proposer: proposer,
                   humanReadableMessage: request.humanReadable,
                   signable: request.signable)
    }
    
    override func start(with pin: String) {
        guard address.lowercased() == request.address.lowercased() else {
            Logger.web3.error(category: "Sign", message: "Mismatched Address")
            state = .signingFailed(SigningError.mismatchedAddress)
            return
        }
        super.start(with: pin)
    }
    
    override func send(signature: String) async {
        do {
            let response = RPCResult.response(AnyCodable(signature))
            try await Web3Wallet.instance.respond(topic: request.raw.topic,
                                                  requestId: request.raw.id,
                                                  response: response)
            Logger.web3.info(category: "Sign", message: "Signature sent")
            await MainActor.run {
                self.state = .success
                self.hasSignatureSent = true
            }
        } catch {
            Logger.web3.error(category: "Sign", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
    override func reject() {
        Task {
            let error = JSONRPCError(code: 0, message: "User Rejected")
            try await Web3Wallet.instance.respond(topic: request.raw.topic, requestId: request.raw.id, response: .error(error))
        }
    }
    
}

final class Web3SignWithBrowserWalletOperation: Web3SignOperation {
    
    private let sendImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        address: String,
        proposer: Web3Proposer,
        humanReadableMessage: String,
        signable: WalletConnectDecodedSigningRequest.Signable,
        sendWith sendImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) {
        self.sendImpl = sendImpl
        self.rejectImpl = rejectImpl
        super.init(address: address,
                   proposer: proposer,
                   humanReadableMessage: humanReadableMessage,
                   signable: signable)
    }
    
    override func send(signature: String) async {
        do {
            try await sendImpl?(signature)
            Logger.web3.info(category: "Sign", message: "Signature sent")
            await MainActor.run {
                self.state = .success
                self.hasSignatureSent = true
            }
        } catch {
            Logger.web3.error(category: "Sign", message: "Failed to send: \(error)")
            await MainActor.run {
                self.state = .sendingFailed(error)
            }
        }
    }
    
    override func reject() {
        rejectImpl?()
    }
    
}
