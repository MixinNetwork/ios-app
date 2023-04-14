import Foundation
import Network
import MixinServices

protocol DeviceTransferClientConnectorDelegate: AnyObject {
    
    func deviceTransferClientConnectorDidReady(_ connector: DeviceTransferClientConnector)
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didReceive data: Data)
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didCloseWith reason: DeviceTransferConnectionClosedReason)
    
}

class DeviceTransferClientConnector {
    
    weak var delegate: DeviceTransferClientConnectorDelegate?
    
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "one.mixin.messenger.DeviceTransferClientConnector")
    
    init(host: String, port: UInt16) {
        let host = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(integerLiteral: port)
        let endPoint = NWEndpoint.hostPort(host: host, port: port)
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        connection = NWConnection(to: endPoint, using: parameters)
    }
    
    func start() {
        connection.stateUpdateHandler = connectionStateDidChange(to:)
        connection.start(queue: queue)
    }
    
    func stop() {
        connection.stateUpdateHandler = nil
        connection.cancel()
    }
    
    func send(data: Data, completion: (() -> Void)? = nil) {
        connection.send(content: data, completion: .contentProcessed({ (error) in
            if let error = error {
                Logger.general.debug(category: "DeviceTransferClientConnector", message: "Failed to send: \(error.localizedDescription)")
            }
            completion?()
        }))
    }
    
}

extension DeviceTransferClientConnector {
    
    private func connectionStateDidChange(to state: NWConnection.State) {
        Logger.general.debug(category: "DeviceTransferClientConnector", message: "Connection State: \(state)")
        switch state {
        case .ready:
            receive()
            delegate?.deviceTransferClientConnectorDidReady(self)
        case .failed(let error):
            Logger.general.debug(category: "DeviceTransferClientConnector", message: "Connection error: \(error.localizedDescription)")
            delegate?.deviceTransferClientConnector(self, didCloseWith: .exception(error))
        default:
            break
        }
    }
    
    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { (data, _, isComplete, error) in
            if let data, !data.isEmpty {
                self.delegate?.deviceTransferClientConnector(self, didReceive: data)
            }
            if isComplete {
                Logger.general.debug(category: "DeviceTransferClientConnector", message: "Receive isComplete")
                self.delegate?.deviceTransferClientConnector(self, didCloseWith: .completed)
            } else if let error {
                Logger.general.debug(category: "DeviceTransferClientConnector", message: "Receive error \(error.localizedDescription)")
                self.delegate?.deviceTransferClientConnector(self, didCloseWith: .exception(error))
            } else {
                self.receive()
            }
        }
    }
    
}
