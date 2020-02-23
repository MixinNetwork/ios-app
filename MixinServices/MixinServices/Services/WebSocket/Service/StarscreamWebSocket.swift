import Starscream

class StarscreamWebSocket: WebSocketProvider {

    private let host: String

    private var socket: WebSocket?

    var delegate: WebSocketProviderDelegate?
    var serverTime: String?
    var isConnected: Bool = false
    var queue: DispatchQueue

    init(host: String, queue: DispatchQueue) {
        self.host = host
        self.queue = queue
    }

    func connect(request: URLRequest) {
        self.socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.callbackQueue = queue
        socket?.connect()
    }

    func disconnect(closeCode: UInt16) {
        socket?.disconnect()
        socket = nil
    }

    func sendPing() {
        socket?.write(ping: Data())
    }

    func send(data: Data) {
        socket?.write(data: data)
    }

}

extension StarscreamWebSocket: WebSocketDelegate {

    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            isConnected = true
            serverTime = headers["X-Server-Time"]
            print("websocket is connected: \(headers)...serverTime:\(serverTime)")
        case let .disconnected(reason, code):
            isConnected = false
            handlerDisconnected(reason: reason, code: code)
        case let .binary(data):
            delegate?.websocketDidReceiveData(socket: self, data: data)
        case .pong:
            delegate?.websocketDidReceivePong(socket: self)
        case let .viablityChanged(isViable):
            print("===========didReceive...viablityChanged...isViable:\(isViable)")
            if !isViable {
                delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
            }
        case let .reconnectSuggested(isBetter):
            print("===========didReceive...reconnectSuggested...isBetter:\(isBetter)")
            if isBetter {
                disconnect(closeCode: CloseCode.reconnect)
            }
        case .cancelled:
            isConnected = false
            print("===========didReceive...cancelled...")
        case .error(let error):
            isConnected = false
            handleError(error: error)
        default:
            break
        }
    }

    private func handlerDisconnected(reason: String, code: UInt16) {
        print("websocket is disconnected: \(reason) with code: \(code)")

        delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
    }

    private func handleError(error: Error?) {
        if let err = error as? FoundationTransportError {
            switch err {
            case .timeout:
                delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: true)
                return
            case .invalidRequest:
                reporter.report(error: MixinServicesError.websocketError(errType: "invalidRequest", errMessage: err.localizedDescription, errCode: Int(err.errorCode)))
            case .invalidOutputStream:
                reporter.report(error: MixinServicesError.websocketError(errType: "invalidOutputStream", errMessage: err.localizedDescription, errCode: Int(err.errorCode)))
            }
        } else if let error = error as? WSError {
            let errType: String
            switch error.type {
            case .compressionError:
                errType = "compressionError"
            case .securityError:
                errType = "securityError"
            case .protocolError:
                errType = "protocolError"
            case .serverError:
                errType = "serverError"
            }
            #if DEBUG
            print("[StarscreamWebSocket][\(errType)][\(error.code)]...\(error.message)")
            #endif
            reporter.report(error: MixinServicesError.websocketError(errType: errType, errMessage: error.message, errCode: Int(error.code)))
        } else if let err = error {
            reporter.report(error: err)
        }

        delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
    }


}
