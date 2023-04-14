import Foundation
import MixinServices
import Network
import Combine

class DeviceTransferClient: DeviceTransferServiceProvidable {
    
    @Published private(set) var displayState: DeviceTransferDisplayState = .preparing
    
    var composer: DeviceTransferDataComposer
    var parser: DeviceTransferDataParser
    
    private weak var syncProgressTimer: Timer?
    
    private lazy var writer = DeviceTransferClientMessageWriter(client: self)
    private lazy var speedTester = DeviceTransferSpeedTester()
    
    private let connector: DeviceTransferClientConnector
    private let code: Int
    
    init(host: String, port: UInt16, code: Int) {
        self.code = code
        composer = DeviceTransferDataComposer()
        parser = DeviceTransferDataParser()
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
            if let total = command.total {
                startTimer()
                startSpeedTester()
                displayState = .transporting(processedCount: 0, totalCount: total)
            } else {
                displayState = .transporting(processedCount: 0, totalCount: 0)
            }
        case .finish:
            displayState = .finished
            invalidateTimer()
            stopSpeedTester()
            let command = DeviceTransferCommand(action: .finish)
            if let data = composer.commandData(command: command) {
                send(data: data)
            }
        case .pull, .push, .progress, .connect:
            break
        }
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseMessage message: Data) {
        updateProgressIfNeeded()
        writer.take(message)
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFile fileURL: URL) {
        updateProgressIfNeeded()
        Logger.general.debug(category: "DeviceTransferDataParser", message: "Receive file: \(fileURL)")
    }
    
    func deviceTransferDataParser(_ parser: DeviceTransferDataParser, didParseFailed error: DeviceTransferDataParserError) {
        Logger.general.debug(category: "DeviceTransferClient", message: "Parse failed: \(error)")
        displayState = .failed(.exception(error))
        connector.stop()
        invalidateTimer()
        stopSpeedTester()
    }
    
}

extension DeviceTransferClient: DeviceTransferClientConnectorDelegate {
    
    func deviceTransferClientConnectorDidReady(_ connector: DeviceTransferClientConnector) {
        displayState = .connected
        let connectCommand = DeviceTransferCommand(action: .connect, code: code, userId: myUserId)
        if let commandData = DeviceTransferDataComposer().commandData(command: connectCommand) {
            send(data: commandData)
            Logger.general.debug(category: "DeviceTransferClient", message: "Send connect command: \(connectCommand)")
        }
    }
    
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didReceive data: Data) {
        parser.parse(data)
        speedTester.send(data: data)
    }
    
    func deviceTransferClientConnector(_ connector: DeviceTransferClientConnector, didCloseWith reason: DeviceTransferConnectionClosedReason) {
        invalidateTimer()
        stopSpeedTester()
        switch reason {
        case .exception(let error):
            displayState = .failed(.exception(error))
        case .completed:
            displayState = .closed
        case .permissionDenied:
            displayState = .failed(.permissionDenied)
        case .mismatchedCode, .mismatchedUserId:
            break
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
            stopSpeedTester()
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
            let timer = Timer.scheduledTimer(timeInterval: 1,
                                             target: self,
                                             selector: #selector(self.syncProgress),
                                             userInfo: nil,
                                             repeats: true)
            self.syncProgressTimer = timer
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func startSpeedTester() {
        DispatchQueue.main.async {
            self.speedTester.startTimer()
        }
    }
    
    private func stopSpeedTester() {
        DispatchQueue.main.async {
            self.speedTester.stop()
        }
    }
    
    @objc private func syncProgress() {
        let progress: Double
        switch displayState {
        case .finished, .closed:
            progress = 100
        case let .transporting(processedCount, totalCount):
            progress = Double(processedCount) / Double(totalCount) * 100
        case .connected, .failed, .preparing, .ready:
            progress = 0
        }
        let command = DeviceTransferCommand(action: .progress, progress: progress)
        if let data = composer.commandData(command: command) {
            Logger.general.debug(category: "DeviceTransferClient", message: "Send Progress: \(progress)")
            send(data: data)
        }
    }
    
}