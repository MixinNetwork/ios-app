import Foundation
import Network
import MixinServices
import Combine

class DeviceTransferServer: DeviceTransferServiceProvidable {
    
    @Published var displayState: DeviceTransferDisplayState = .preparing
    
    var canSendData: Bool {
        switch displayState {
        case .ready, .transporting:
            return true
        default:
            return false
        }
    }
    
    let port: UInt16
    let code: Int
    
    var composer: DeviceTransferDataComposer
    var parser: DeviceTransferDataParser
    var connectionCommand: DeviceTransferCommand?
    
    private lazy var sender = DeviceTransferServerDataSender(server: self)
    
    private let connector: DeviceTransferServerConnector
    
    init() throws {
        code = Int(arc4random_uniform(1000))
        port = NetworkPort.randomAvailablePort()
        composer = DeviceTransferDataComposer()
        parser = DeviceTransferDataParser()
        connector = try DeviceTransferServerConnector(port: port)
        connector.delegate = self
        parser.delegate = self
    }
    
    func start() {
        connector.start()
    }
    
    func stop() {
        connector.stopConnection()
    }
    
    func send(data: Data, completion: (() -> Void)? = nil) {
        connector.send(data: data, completion: completion)
    }
    
}

extension DeviceTransferServer: DeviceTransferDataParserDelegate {
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseCommand command: DeviceTransferCommand) {
        switch command.action {
        case .connect:
            guard command.userId == myUserId else {
                displayState = .failed(.mismatchedUserId)
                return
            }
            guard command.code == code else {
                displayState = .failed(.mismatchedCode)
                return
            }
            connectionCommand = command
            displayState = .connected
            sender.startTransfer()
        case .finish:
            displayState = .closed
            connector.stopConnection()
        case .progress:
            if let progress = command.progress, case let .transporting(_, totalCount) = displayState {
                let currentProcessedCount = Int(Double(totalCount) * progress / 100.0)
                displayState = .transporting(processedCount: currentProcessedCount, totalCount: totalCount)
            }
        case .pull, .push, .start:
            break
        }
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseMessage message: Data) {
        
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFile fileURL: URL) {
        
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFailed error: DeviceTransferDataParserError) {
        Logger.general.info(category: "DeviceTransferServer", message: "Parse failed: \(error)")
    }
    
}

extension DeviceTransferServer: DeviceTransferServerConnectorDelegate {
    
    func deviceTransferServerConnectorDidReady(_ connector: DeviceTransferServerConnector) {
        displayState = .ready
    }
    
    func deviceTransferServerConnectorDidConnect(_ connector: DeviceTransferServerConnector) {
        displayState = .connected
    }
    
    func deviceTransferServerConnector(_ connector: DeviceTransferServerConnector, didReceive data: Data) {
        parser.parse(data)
    }
    
    func deviceTransferServerConnector(_ connector: DeviceTransferServerConnector, didCloseWith reason: DeviceTransferConnectionClosedReason) {
        displayState = .failed(reason)
    }
    
}
