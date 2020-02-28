import Foundation

internal class HeartbeatService {
    
    var onOffline: (() -> Void)?
    
    private let socket: WebSocketProvider
    private let interval: TimeInterval = 15
    
    private weak var timer: Timer?
    
    private var sentCount = 0
    private var receivedCount = 0
    private var isRunning = false
    
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
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true, block: { [weak self] (timer) in
            guard let self = self else {
                return
            }
            self.socket.queue.async {
                guard self.socket.isConnected else {
                    return
                }
                // Currently both start and stop are called from socket's callback queue
                // Dispatch to the queue to avoid data race or locking overhead
                if self.sentCount > self.receivedCount {
                    self.onOffline?()
                } else {
                    self.socket.sendPing()
                    self.sentCount += 1
                }
            }
        })
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isRunning = true
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
