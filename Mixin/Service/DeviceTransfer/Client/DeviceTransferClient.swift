import Foundation
import MixinServices
import Network
import Combine

class DeviceTransferClient: DeviceTransferServiceProvidable {
    
    @Published private(set) var displayState: DeviceTransferDisplayState = .preparing
    
    var composer: DeviceTransferDataComposer
    var parser: DeviceTransferDataParser
    var connectionCommand: DeviceTransferCommand?
    var speedTester: DeviceTransferSpeedTester
    
    var isTransferFinished = false
    
    private weak var syncProgressTimer: Timer?
    
    private lazy var writer: DeviceTransferClientDataWriter = {
        let writer = DeviceTransferClientDataWriter(client: self)
        writer.delegate = self
        return writer
    }()
        
    private let connector: DeviceTransferClientConnector
    private let code: Int
    
    deinit {
        writer.cleanFiles()
    }
    
    init(host: String, port: UInt16, code: Int) {
        self.code = code
        composer = DeviceTransferDataComposer()
        parser = DeviceTransferDataParser()
        speedTester = DeviceTransferSpeedTester()
        connector = DeviceTransferClientConnector(host: host, port: port)
        connector.delegate = self
        parser.delegate = self
    }
    
    func start() {
        connector.start()
    }
    
    func stop() {
        connector.stop()
    }
    
    func send(data: Data, completion: (() -> Void)? = nil) {
        connector.send(data: data, completion: completion)
    }
    
}

extension DeviceTransferClient: DeviceTransferDataParserDelegate {
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseCommand command: DeviceTransferCommand) {
        switch command.action {
        case .start:
            guard let total = command.total else {
                Logger.general.info(category: "DeviceTransferClient", message: "No total count")
                displayState = .failed(.completed)
                return
            }
            Logger.general.info(category: "DeviceTransferClient", message: "Total messages \(total)")
            connectionCommand = command
            startSpeedTester()
            startTimer()
            writer.canWriteData = true
            displayState = .transporting(processedCount: 0, totalCount: total)
        case .finish:
            isTransferFinished = true
            writer.parseDataIfNeeded()
            displayState = .finished
            stopSpeedTester()
            invalidateTimer()
            let command = DeviceTransferCommand(action: .finish)
            if let data = composer.commandData(command: command) {
                send(data: data)
            }
        case .pull, .push, .progress, .connect, .cancel:
            break
        }
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseMessage message: Data) {
        updateProgressIfNeeded()
        writer.take(message)
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFile fileURL: URL?) {
        updateProgressIfNeeded()
        Logger.general.debug(category: "DeviceTransferClient", message: "Receive file: \(String(describing: fileURL))")
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFailed error: DeviceTransferDataParserError) {
        Logger.general.info(category: "DeviceTransferClient", message: "Parse failed: \(error)")
        displayState = .failed(.exception(error))
        connector.stop()
        stopSpeedTester()
        invalidateTimer()
    }
    
}

extension DeviceTransferClient: DeviceTransferClientConnectorDelegate {
    
    func deviceTransferClientConnectorDidReady(_ connector: DeviceTransferClientConnector) {
        displayState = .connected
        let connectCommand = DeviceTransferCommand(action: .connect, code: code, userId: myUserId)
        if let commandData = DeviceTransferDataComposer().commandData(command: connectCommand) {
            send(data: commandData)
            Logger.general.info(category: "DeviceTransferClient", message: "Send connect command: \(connectCommand)")
        }
    }
    
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didReceive data: Data) {
        parser.parse(data)
        speedTester.take(data)
    }
    
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didCloseWith reason: DeviceTransferConnectionClosedReason) {
        stopSpeedTester()
        invalidateTimer()
        guard !isTransferFinished else {
            return
        }
        writer.canWriteData = false
        switch reason {
        case .exception(let error):
            displayState = .failed(.exception(error))
        case .completed:
            displayState = .failed(.completed)
        case .mismatchedCode, .mismatchedUserId:
            break
        }
    }
    
}

extension DeviceTransferClient: DeviceTransferClientDataWriterDelegate {
    
    func deviceTransferClientDataWriter(_ writer: DeviceTransferClientDataWriter, update progress: Float) {
        guard isTransferFinished else {
            return
        }
        if progress < 1 {
            displayState = .importing(progress)
        } else {
            ConversationDAO.shared.updateLastMessageIdAndCreatedAt()
            displayState = .closed
        }
    }
    
}

extension DeviceTransferClient {
    
    private func updateProgressIfNeeded() {
        guard case let .transporting(processedCount, totalCount) = displayState else {
            return
        }
        let currentProcessedCount = processedCount + 1
        if currentProcessedCount == totalCount {
            displayState = .finished
            invalidateTimer()
        } else {
            displayState = .transporting(processedCount: currentProcessedCount, totalCount: totalCount)
        }
    }
    
    private func invalidateTimer() {
        DispatchQueue.main.async {
            self.syncProgressTimer?.invalidate()
            self.syncProgressTimer = nil
        }
    }
    
    private func startTimer() {
        DispatchQueue.main.async {
            self.syncProgressTimer = Timer.scheduledTimer(timeInterval: 1,
                                                          target: self,
                                                          selector: #selector(self.syncProgress),
                                                          userInfo: nil,
                                                          repeats: true)
        }
    }
    
    @objc private func syncProgress() {
        let progress: Double
        switch displayState {
        case .finished, .closed:
            progress = 100
        case let .transporting(processedCount, totalCount):
            progress = Double(processedCount) / Double(totalCount) * 100
            Logger.general.info(category: "DeviceTransferClient", message: "Processed: \(processedCount) Total: \(totalCount) Progress: \(progress)")
        case .connected, .failed, .preparing, .ready, .importing:
            progress = 0
        }
        let command = DeviceTransferCommand(action: .progress, progress: progress)
        if let data = composer.commandData(command: command) {
            Logger.general.debug(category: "DeviceTransferClient", message: "Send Progress: \(progress)")
            send(data: data)
        }
    }
    
}
