import UIKit
import web3
import MixinServices

protocol WalletConnectSession {
    
    var topic: String { get }
    var iconURL: URL? { get }
    var name: String { get }
    var description: String? { get }
    var host: String { get }
    
    func disconnect() async throws
    
}

extension WalletConnectSession {
    
    static func makeEthereumClient(with chain: WalletConnectService.Chain) -> EthereumHttpClient {
        let network: EthereumNetwork
        switch chain {
        case .ethereum:
            network = .mainnet
        case .goerli:
            network = .goerli
        default:
            network = .custom("\(chain.id)")
        }
        Logger.walletConnect.info(category: "WalletConnectSession", message: "New client with: \(chain)")
        return EthereumHttpClient(url: chain.rpcServerURL, network: network)
    }
    
    @MainActor
    func requestSigning<Request, Signable>(
        with request: Request,
        decodeContent: (Request) throws -> (message: WalletConnectMessage<Signable>, address: String),
        reject: @escaping (WalletConnectRejectionReason) -> Void,
        approve: @escaping (WalletConnectMessage<Signable>, EthereumAccount) throws -> Void
    ) {
        do {
            let (message, address) = try decodeContent(request)
            let signRequest = SignRequestViewController(requester: .walletConnect(self), message: message.humanReadable)
            signRequest.onReject = {
                reject(.userRejected)
            }
            signRequest.onApprove = { priv in
                let storage = InPlaceKeyStorage(raw: priv)
                let account = try EthereumAccount(keyStorage: storage)
                guard address.lowercased() == account.address.asString() else {
                    reject(.mismatchedAddress)
                    return
                }
                try approve(message, account)
            }
            let authentication = AuthenticationViewController(intentViewController: signRequest)
            WalletConnectService.shared.presentRequest(viewController: authentication)
        } catch {
            let title = R.string.localizable.request_rejected()
            let message = R.string.localizable.unable_to_decode_the_request(error.localizedDescription)
            WalletConnectService.shared.presentRejection(title: title, message: message)
            reject(.exception(error))
        }
    }
    
}
