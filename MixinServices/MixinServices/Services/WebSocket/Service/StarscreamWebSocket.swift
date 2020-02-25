import Starscream

class StarscreamWebSocket: WebSocketProvider {

    private let host: String

    private var socket: WebSocket?

    weak var delegate: WebSocketProviderDelegate?
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
        switch closeCode {
        case CloseCode.exit:
            socket?.forceDisconnect()
        default:
            socket?.disconnect()
        }
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
        case let .connected(headers):
            isConnected = true
            serverTime = headers["X-Server-Time"]
            delegate?.websocketDidConnect(socket: self)
        case let .disconnected(reason, code):
            isConnected = false
            traceDisconnect(reason: reason, closeCode: code)
            delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
        case let .binary(data):
            delegate?.websocketDidReceiveData(socket: self, data: data)
        case .pong:
            delegate?.websocketDidReceivePong(socket: self)
        case let .viablityChanged(isViable):
            isConnected = isViable
            if !isViable {
                disconnect(closeCode: CloseCode.reconnect)
                delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
            }
        case let .reconnectSuggested(isBetter):
            if isBetter {
                disconnect(closeCode: CloseCode.reconnect)
                delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
            }
        case .cancelled:
            isConnected = false
        case let .error(error):
            isConnected = false
            handleError(error: error)
        default:
            break
        }
    }

    private func traceDisconnect(reason: String, closeCode: UInt16) {
        var errType = "\(closeCode)"
        switch closeCode {
        case Starscream.CloseCode.normal.rawValue, Starscream.CloseCode.goingAway.rawValue:
            return
        case Starscream.CloseCode.protocolError.rawValue:
            errType = "protocolError"
        case Starscream.CloseCode.protocolUnhandledType.rawValue:
            errType = "protocolUnhandledType"
        case Starscream.CloseCode.noStatusReceived.rawValue:
            errType = "noStatusReceived"
        case Starscream.CloseCode.encoding.rawValue:
            errType = "encoding"
        case Starscream.CloseCode.policyViolated.rawValue:
            errType = "policyViolated"
        case Starscream.CloseCode.messageTooBig.rawValue:
            errType = "messageTooBig"
        default:
            break
        }

        #if DEBUG
        print("[StarscreamWebSocket][\(errType)][\(closeCode)]...\(reason)")
        #endif
        reporter.report(error: MixinServicesError.websocketError(errType: errType, errMessage: reason, errCode: Int(closeCode)))
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
