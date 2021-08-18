import SocketRocket

class RocketWebSocket: NSObject, WebSocketProvider {

    private let host: String

    private var socket: SRWebSocket?

    var delegate: WebSocketProviderDelegate?
    var serverTime: String?
    var isConnected: Bool {
        get {
            guard let socket = self.socket else {
                return false
            }
            return socket.readyState == .OPEN
        }
        set { }
    }
    var queue: DispatchQueue

    init(host: String, queue: DispatchQueue) {
        self.host = host
        self.queue = queue
    }

    func connect(request: URLRequest) {
        socket = SRWebSocket(urlRequest: request)
        socket?.delegateDispatchQueue = queue
        socket?.delegate = self
        socket?.open()
    }

    func disconnect(closeCode: UInt16) {
        socket?.delegate = nil
        socket?.close()
        socket = nil
    }

    func sendPing() {
        try? socket?.sendPing(Data())
    }

    func send(data: Data) {
        socket?.send(data)
    }

}

extension RocketWebSocket: SRWebSocketDelegate {

    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        guard let data = message as? Data else {
            return
        }
        delegate?.websocketDidReceiveData(socket: self, data: data)
    }

    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        if let headers = webSocket.receivedHTTPHeaders {
            serverTime = CFHTTPMessageCopyHeaderFieldValue(headers, "x-server-time" as CFString)?.takeRetainedValue() as String?
        }
        delegate?.websocketDidConnect(socket: self)
    }

    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        guard let err = error else {
            return
        }
        let nsError = error as NSError
        Logger.general.error(category: "RocketWebSocket", message: "Websocket failed with: \(err), host: \(MixinHost.webSocket)")

        if (nsError.domain == "com.squareup.SocketRocket" && nsError.code == 504)
            || (nsError.domain == NSPOSIXErrorDomain && nsError.code == 61) || nsError.domain == SRWebSocketErrorDomain {
            // Connection time out or refused
            delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: true)
        } else {
            delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)

            if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                return
            }
            reporter.report(error: err)
        }
    }

    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        let errType: String
        var errMessage = reason ?? ""
        switch SRStatusCode(rawValue: code) {
        case .codeNormal, .codeGoingAway:
            return
        case .codeProtocolError:
            errType = "protocolError"
        case .codeUnhandledType:
            errType = "unhandledType"
        case .noStatusReceived:
            errType = "noStatusReceived"
        case .codeAbnormal:
            errType = "abnormal"
        case .codeInvalidUTF8:
            errType = "invalidUTF8"
        case .codePolicyViolated:
            errType = "policyViolated"
        case .codeMessageTooBig:
            errType = "messageTooBig"
        case .codeMissingExtension:
            errType = "missingExtension"
        case .codeInternalError:
            errType = "internalError"
        case .codeServiceRestart:
            errType = "serviceRestart"
        case .codeTryAgainLater:
            errType = "tryAgainLater"
        case .codeTLSHandshake:
            errType = "TLSHandshake"
        default:
            errType = "\(code)"
        }

        Logger.general.error(category: "RocketWebSocket", message: "Websocket closed with: \(errType), code: \(code), wasClean:\(wasClean), reaseon: \(reason)")
        
        reporter.report(error: MixinServicesError.websocketError(errType: errType, errMessage: errMessage, errCode: code))
        delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
    }

    func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        delegate?.websocketDidReceivePong(socket: self)
    }

}
