import Foundation

@available(iOS 13.0, *)
class NativeWebSocket: NSObject, WebSocketProvider {

    private let url: URL
    private let protocols: [String]

    private var socket: URLSessionWebSocketTask?
    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    var delegate: WebSocketProviderDelegate?

    required init(url: URL, protocols: [String]?) {
        self.url = url
        self.protocols = protocols ?? []
    }


    func connect() {
        socket = urlSession.webSocketTask(with: url, protocols: protocols)
        socket?.resume()
        socket?.receive(completionHandler: { [weak self](result) in
            guard let self = self else {
                return
            }
            switch result {
            case let .success(message):
                guard case let .data(data) = message else  {
                    return
                }
                self.delegate?.websocketDidReceiveData(socket: self, data: data)
            case let .failure(error):
                break
            }
        })
    }

    func disconnect() {
        socket?.cancel()
        socket = nil
        delegate?.websocketDidDisconnect(socket: self, error: nil)
    }

    func sendPing() {
        socket?.sendPing(pongReceiveHandler: { (error) in

        })
    }

    func send(data: Data) {
        socket?.send(URLSessionWebSocketTask.Message.data(data)) { (error) in

        }
    }

}

@available(iOS 13.0, *)
extension NativeWebSocket: URLSessionWebSocketDelegate {

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        delegate?.websocketDidConnect(socket: self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        delegate?.websocketDidDisconnect(socket: self)
    }

}
