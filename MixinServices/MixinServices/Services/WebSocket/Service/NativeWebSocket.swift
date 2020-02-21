import Foundation

@available(iOS 13.0, *)
class NativeWebSocket: NSObject, WebSocketProvider {

    private let host: String

    private lazy var urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var socket: URLSessionWebSocketTask?

    var delegate: WebSocketProviderDelegate?
    var serverTime: String?
    var isConnected: Bool = false
    var queue: DispatchQueue

    init(host: String, queue: DispatchQueue) {
        self.host = host
        self.queue = queue
    }

    func connect(request: URLRequest) {
        socket = urlSession.webSocketTask(with: request)
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
                #if DEBUG
                print("[NativeWebSocket]Failed to receive message: \(error)")
                #endif
                reporter.report(error: error)
            }
        })
    }

    func disconnect(closeCode: UInt16) {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    func sendPing() {
        socket?.sendPing(pongReceiveHandler: { (error) in
            if let err = error {
                reporter.report(error: err)
            }
        })
    }

    func send(data: Data) {
        socket?.send(URLSessionWebSocketTask.Message.data(data)) { (error) in
            if let err = error {
                reporter.report(error: err)
            }
        }
    }

}

@available(iOS 13.0, *)
extension NativeWebSocket: URLSessionWebSocketDelegate {

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        delegate?.websocketDidConnect(socket: self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let errType: String
        var errMessage = ""
        var isSwitchNetwork = false
        switch closeCode {
        case .invalid:
            errType = "invalid"
        case .normalClosure:
            errType = "normalClosure"
        case .goingAway:
            errType = "goingAway"
        case .protocolError:
            errType = "protocolError"
        case .unsupportedData:
            errType = "unsupportedData"
        case .noStatusReceived:
            errType = "noStatusReceived"
            isSwitchNetwork = true
        case .abnormalClosure:
            errType = "abnormalClosure"
        case .invalidFramePayloadData:
            errType = "invalidFramePayloadData"
        case .policyViolation:
            errType = "policyViolation"
        case .messageTooBig:
            errType = "messageTooBig"
        case .mandatoryExtensionMissing:
            errType = "mandatoryExtensionMissing"
        case .internalServerError:
            errType = "internalServerError"
        case .tlsHandshakeFailure:
            errType = "tlsHandshakeFailure"
        }

        #if DEBUG
        print("[NativeWebSocket][\(errType)][\(closeCode.rawValue)]...\(reason ?? Data())")
        #endif

        delegate?.websocketDidDisconnect(socket: self, isSwitchNetwork: isSwitchNetwork)

        if closeCode != .normalClosure {
            reporter.report(error: MixinServicesError.websocketError(errType: errType, errMessage: errType, errCode: closeCode.rawValue))
        }
    }

}
