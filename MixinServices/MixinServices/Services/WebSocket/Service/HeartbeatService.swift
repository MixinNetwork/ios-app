import Foundation

internal class HeartbeatService {
    
    var onOffline: (() -> Void)?
    
    private let socket: WebSocketProvider
    private let interval: TimeInterval = 15
    
    private weak var timer: Timer?
    
    private var sentCount = 0
    private var receivedCount = 0
    private var isRunning = false
    private var lastSendPingTime = Date()
    
    init(socket: WebSocketProvider) {
        self.socket = socket
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func start() {
        guard !isRunning else {
            return
        }
        isRunning = true
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true, block: { [weak self] (timer) in
            self?.sendPing()
        })
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func sendPing() {
        socket.queue.async { [weak self] in
            guard let self = self else {
                return
            }

            // Currently both start and stop are called from socket's callback queue
            // Dispatch to the queue to avoid data race or locking overhead
            if self.sentCount > self.receivedCount {
                self.onOffline?()
            } else {
                guard self.socket.isConnected else {
                    self.socket.delegate?.websocketDidDisconnect(socket: self.socket, isSwitchNetwork: false)
                    return
                }
                self.lastSendPingTime = Date()
                self.socket.sendPing()
                self.sentCount += 1
            }
        }
    }

    func checkConnect() {
        guard -lastSendPingTime.timeIntervalSinceNow >= 5 else {
            return
        }
        sendPing()
    }
    
    func stop() {
        guard isRunning else {
            return
        }
        timer?.invalidate()
        sentCount = 0
        receivedCount = 0
        isRunning = false
    }

    func websocketDidReceivePong() {
        guard isRunning else {
            return
        }
        receivedCount += 1
    }
    
}
