

protocol WebSocketProvider {

    var delegate: WebSocketProviderDelegate? { get set }

    init(url: URL, protocols: [String]?)

    func connect()

    func disconnect()

    func sendPing()

    func send(data: Data)

}


protocol WebSocketProviderDelegate: class {
    func websocketDidConnect(socket: WebSocketProvider)
    func websocketDidDisconnect(socket: WebSocketProvider)
    func websocketDidReceiveData(socket: WebSocketProvider, data: Data)
}
