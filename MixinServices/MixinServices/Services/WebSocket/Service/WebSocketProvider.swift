

protocol WebSocketProvider {

    var delegate: WebSocketProviderDelegate? { get set }

    var serverTime: String? { get set }

    var isConnected: Bool { get set }

    var queue: DispatchQueue { get set }

    func connect(request: URLRequest)

    func disconnect(closeCode: UInt16)

    func sendPing()

    func send(data: Data)

}

protocol WebSocketProviderDelegate: AnyObject {
    func websocketDidConnect(socket: WebSocketProvider)
    func websocketDidDisconnect(socket: WebSocketProvider, isSwitchNetwork: Bool)
    func websocketDidReceiveData(socket: WebSocketProvider, data: Data)
    func websocketDidReceivePong(socket: WebSocketProvider)
}

enum CloseCode {
    static let exit: UInt16 = 9999
    static let failure: UInt16 = 9998
    static let reconnect: UInt16 = 9997
}
