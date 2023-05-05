import Foundation
import Network
import MixinServices

protocol DeviceTransferServerConnectorDelegate: AnyObject {
    
    func deviceTransferServerConnectorDidReady(_ connector: DeviceTransferServerConnector)
    func deviceTransferServerConnectorDidConnect(_ connector: DeviceTransferServerConnector)
    func deviceTransferServerConnector(_ connector: DeviceTransferServerConnector, didReceive data: Data)
    func deviceTransferServerConnector(_ connector: DeviceTransferServerConnector, didCloseWith reason: DeviceTransferConnectionClosedReason)
    
}

final class DeviceTransferServerConnector {
    
    weak var delegate: DeviceTransferServerConnectorDelegate?
    
    let listener: NWListener
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.DeviceTransferServerConnector")
    
    private var connection: NWConnection?
    
    init(port: UInt16) throws {
        let port = NWEndpoint.Port(integerLiteral: port)
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        listener = try NWListener(using: parameters, on: port)
    }
    
    func start() {
        listener.stateUpdateHandler = listenerStateDidChange(to:)
        listener.newConnectionHandler = newConnectionDidAccept(connection:)
        listener.start(queue: queue)
    }
    
    func stopConnection() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
    }
    
    func send(data: Data, completion: (() -> Void)? = nil) {
        guard let connection else {
            Logger.general.info(category: "DeviceTransferServerConnector", message: "No connection")
            completion?()
            delegate?.deviceTransferServerConnector(self, didCloseWith: .completed)
            return
        }
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error {
                Logger.general.info(category: "DeviceTransferServerConnector", message: "Failed to send: \(error.localizedDescription)")
            }
            completion?()
        }))
    }
    
}

extension DeviceTransferServerConnector {
    
    private func listenerStateDidChange(to state: NWListener.State) {
        switch state {
        case .ready:
            Logger.general.info(category: "DeviceTransferServerConnector", message:("Listener Ready on \(NetworkInterface.firstEthernetHostname() ?? "(null)"), port: \(listener.port?.rawValue ?? 0)"))
            delegate?.deviceTransferServerConnectorDidReady(self)
        case .failed(let error):
            Logger.general.info(category: "DeviceTransferServerConnector", message:("Listener failed: \(error)"))
            delegate?.deviceTransferServerConnector(self, didCloseWith: .exception(error))
        default:
            Logger.general.info(category: "DeviceTransferServerConnector", message:("Listener State: \(state)"))
            break
        }
    }
    
    private func newConnectionDidAccept(connection: NWConnection) {
        self.connection = connection
        receive(on: connection)
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                Logger.general.info(category: "DeviceTransferServerConnector", message: "Connection Ready")
                self.delegate?.deviceTransferServerConnectorDidConnect(self)
            case .failed(let error):
                Logger.general.info(category: "DeviceTransferServerConnector", message:"Connection failed: \(error)")
                self.delegate?.deviceTransferServerConnector(self, didCloseWith: .exception(error))
            default:
                Logger.general.info(category: "DeviceTransferServerConnector", message:("Connection State: \(newState)"))
                break
            }
        }
        connection.start(queue: queue)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                self.delegate?.deviceTransferServerConnector(self, didReceive: data)
            }
            if isComplete {
                Logger.general.info(category: "DeviceTransferServerConnector", message: "Receive isComplete")
                self.delegate?.deviceTransferServerConnector(self, didCloseWith: .completed)
            } else if let error = error {
                Logger.general.info(category: "DeviceTransferServerConnector", message: "Receive error: \(error)")
                self.delegate?.deviceTransferServerConnector(self, didCloseWith: .exception(error))
            } else {
                self.receive(on: connection)
            }
        }
    }
    
}
