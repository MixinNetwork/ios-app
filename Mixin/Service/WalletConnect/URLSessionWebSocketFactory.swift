import Foundation
import Web3Wallet
import MixinServices

final class URLSessionWebSocketFactory: NSObject, WebSocketFactory, URLSessionWebSocketDelegate {
    
    private var session: URLSession!
    private var workers = NSHashTable<URLSessionWebSocketWorker>(options: .weakMemory)
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }
    
    func create(with url: URL) -> WebSocketConnecting {
        let worker = URLSessionWebSocketWorker(url: url)
        Queue.main.autoSync {
            workers.add(worker)
        }
        return worker
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let enumerator = workers.objectEnumerator()
        while let worker = enumerator.nextObject() as! URLSessionWebSocketWorker? {
            if worker.task == webSocketTask {
                worker.onConnect?()
                return
            }
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let enumerator = workers.objectEnumerator()
        while let worker = enumerator.nextObject() as! URLSessionWebSocketWorker? {
            if worker.task == webSocketTask {
                worker.onDisconnect?(nil)
                return
            }
        }
    }
    
}

fileprivate final class URLSessionWebSocketWorker: WebSocketConnecting {
    
    var isConnected: Bool {
        task.state == .running
    }
    
    var onConnect: (() -> Void)?
    
    var onDisconnect: ((Error?) -> Void)?
    
    var onText: ((String) -> Void)?
    
    var request: URLRequest
    
    func connect() {
        switch task.state {
        case .running:
            break
        case .suspended:
            resumeCurrentTask()
        case .canceling, .completed:
            task = URLSession.shared.webSocketTask(with: request)
            resumeCurrentTask()
        @unknown default:
            break
        }
    }
    
    func disconnect() {
        task.cancel()
    }
    
    func write(string: String, completion: (() -> Void)?) {
        Logger.walletConnect.debug(category: "URLSessionWebSocketWorker", message: "Write: \(string)")
        task.send(.string(string)) { _ in
            completion?()
        }
    }
    
    private(set) var task: URLSessionWebSocketTask
    
    init(url: URL) {
        request = URLRequest(url: url)
        task = URLSession.shared.webSocketTask(with: request)
    }
    
    private func resumeCurrentTask() {
        task.resume()
        task.receive(completionHandler: dispatch(result:))
    }
    
    private func dispatch(result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case let .success(.string(message)):
            Logger.walletConnect.debug(category: "URLSessionWebSocketWorker", message: "Read: \(message)")
            self.onText?(message)
            fallthrough
        case .success:
            task.receive(completionHandler: dispatch(result:))
        case .failure:
            break
        }
    }
    
}
