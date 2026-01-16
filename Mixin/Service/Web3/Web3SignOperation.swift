import Foundation
import web3
import ReownWalletKit
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
        case invalidSignable
        case invalidSignature
        case unsupportedChain
    }
    
    let wallet: Web3Wallet
    let chain: Web3Chain
    let address: Web3Address
    let proposer: Web3DappProposer
    let signable: WalletConnectDecodedSigningRequest.Signable
    let humanReadableMessage: String
    
    @Published
    fileprivate(set) var state: State = .pending
    
    fileprivate var signature: String?
    fileprivate var hasSignatureSent = false
    
    fileprivate init(
        wallet: Web3Wallet,
        chain: Web3Chain,
        address: Web3Address,
        proposer: Web3DappProposer,
        signable: WalletConnectDecodedSigningRequest.Signable,
        humanReadableMessage: String,
    ) {
        self.wallet = wallet
        self.chain = chain
        self.address = address
        self.proposer = proposer
        self.signable = signable
        self.humanReadableMessage = humanReadableMessage
    }
    
    func start(with pin: String) {
        state = .signing
        Task.detached { [wallet, chain, address, signable] in
            Logger.web3.info(category: "Sign", message: "Will sign")
            let signature: String
            do {
                switch chain.kind {
                case .bitcoin:
                    throw SigningError.unsupportedChain
                case .evm:
                    let account = try await wallet.ethereumAccount(pin: pin, address: address)
                    signature = switch signable {
                    case .raw(let data):
                        try account.signMessage(message: data)
                    case .typed(let data):
                        try account.signMessage(message: data)
                    }
                case .solana:
                    switch signable {
                    case .raw(let message):
                        let priv = try await wallet.solanaPrivateKey(pin: pin, address: address)
                        signature = try Solana.sign(
                            message: message,
                            withPrivateKeyFrom: priv,
                            format: .base58
                        )
                    case .typed:
                        throw SigningError.invalidSignable
                    }
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
        wallet: Web3Wallet,
        chain: Web3Chain,
        address: Web3Address,
        session: WalletConnectSession,
        request: WalletConnectDecodedSigningRequest,
    ) {
        self.session = session
        self.request = request
        super.init(
            wallet: wallet,
            chain: chain,
            address: address,
            proposer: Web3DappProposer(name: session.name, host: session.host),
            signable: request.signable,
            humanReadableMessage: request.humanReadable,
        )
    }
    
    override func start(with pin: String) {
        guard address.destination.lowercased() == request.address.lowercased() else {
            Logger.web3.error(category: "Sign", message: "Mismatched Address")
            state = .signingFailed(SigningError.mismatchedAddress)
            return
        }
        super.start(with: pin)
    }
    
    override func send(signature: String) async {
        do {
            let response = switch chain.kind {
            case .bitcoin:
                throw SigningError.unsupportedChain
            case .evm:
                RPCResult.response(AnyCodable(signature))
            case .solana:
                RPCResult.response(AnyCodable(["signature": signature]))
            }
            try await WalletKit.instance.respond(
                topic: request.raw.topic,
                requestId: request.raw.id,
                response: response
            )
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
            try await WalletKit.instance.respond(
                topic: request.raw.topic,
                requestId: request.raw.id,
                response: .error(error)
            )
        }
    }
    
}

final class Web3SignWithBrowserWalletOperation: Web3SignOperation {
    
    var solanaLoginWithHexSignatureQuirk = false
    
    private let sendImpl: ((String) async throws -> Void)?
    private let rejectImpl: (() -> Void)?
    
    init(
        wallet: Web3Wallet,
        chain: Web3Chain,
        address: Web3Address,
        proposer: Web3DappProposer,
        signable: WalletConnectDecodedSigningRequest.Signable,
        humanReadableMessage: String,
        sendWith sendImpl: @escaping ((String) async throws -> Void),
        rejectWith rejectImpl: @escaping (() -> Void)
    ) {
        self.sendImpl = sendImpl
        self.rejectImpl = rejectImpl
        super.init(
            wallet: wallet,
            chain: chain,
            address: address,
            proposer: proposer,
            signable: signable,
            humanReadableMessage: humanReadableMessage
        )
    }
    
    override func send(signature: String) async {
        do {
            switch chain.kind {
            case .bitcoin:
                throw SigningError.unsupportedChain
            case .evm:
                try await sendImpl?(signature)
            case .solana:
                guard case let .raw(signedMessage) = signable else {
                    throw SigningError.invalidSignable
                }
                if solanaLoginWithHexSignatureQuirk {
                    guard let data = Data(base58EncodedString: signature) else {
                        throw SigningError.invalidSignature
                    }
                    try await sendImpl?(data.hexEncodedString())
                } else {
                    let output: [String: Any] = [
                        "account": ["publicKey": address],
                        "signedMessage": signedMessage.base58EncodedString(),
                        "signature": signature
                    ]
                    let json = try JSONSerialization.data(withJSONObject: output)
                    try await sendImpl?(json.hexEncodedString())
                }
            }
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
