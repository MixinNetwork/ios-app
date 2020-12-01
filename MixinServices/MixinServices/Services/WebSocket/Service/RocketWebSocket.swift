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
        socket?.setDelegateDispatchQueue(queue)
        socket?.delegate = self
        socket?.open()
    }

    func disconnect(closeCode: UInt16) {
        socket?.delegate = nil
        socket?.close()
        socket = nil
    }

    func sendPing() {
        socket?.sendPing(Data())
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
        serverTime = CFHTTPMessageCopyHeaderFieldValue(webSocket.receivedHTTPHeaders, "x-server-time" as CFString)?.takeRetainedValue() as String?
        delegate?.websocketDidConnect(socket: self)
    }

    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        guard let err = error else {
            return
        }
        let nsError = error as NSError
        Logger.write(error: err, extra: "[RocketWebSocket][DidFailWithError]...\(MixinHost.webSocket)")

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
        var errType = "\(code)"
        var errMessage = reason ?? ""
        switch code {
        case SRStatusCodeNormal.rawValue, SRStatusCodeGoingAway.rawValue:
            return
        case SRStatusCodeProtocolError.rawValue:
            errType = "protocolError"
        case SRStatusCodeUnhandledType.rawValue:
            errType = "unhandledType"
        case SRStatusNoStatusReceived.rawValue:
            errType = "noStatusReceived"
        case SRStatusCodeAbnormal.rawValue:
            errType = "abnormal"
        case SRStatusCodeInvalidUTF8.rawValue:
            errType = "invalidUTF8"
        case SRStatusCodePolicyViolated.rawValue:
            errType = "policyViolated"
        case SRStatusCodeMessageTooBig.rawValue:
            errType = "messageTooBig"
        case SRStatusCodeMissingExtension.rawValue:
            errType = "missingExtension"
        case SRStatusCodeInternalError.rawValue:
            errType = "internalError"
        case SRStatusCodeServiceRestart.rawValue:
            errType = "serviceRestart"
        case SRStatusCodeTryAgainLater.rawValue:
            errType = "tryAgainLater"
        case SRStatusCodeTLSHandshake.rawValue:
            errType = "TLSHandshake"
        default:
            break
        }

        let log = "[RocketWebSocket][\(errType)][\(code)]...wasClean:\(wasClean)...\(reason ?? "")"
        #if DEBUG
        NSLog(log)
        #endif
        Logger.write(log: log)
        
        reporter.report(error: MixinServicesError.websocketError(errType: errType, errMessage: errMessage, errCode: code))
        delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: false)
    }

    func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        delegate?.websocketDidReceivePong(socket: self)
    }

}
