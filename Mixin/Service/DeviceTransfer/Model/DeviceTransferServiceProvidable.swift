import Foundation
import Combine
import MixinServices

protocol DeviceTransferServiceProvidable {
    
    var displayState: DeviceTransferDisplayState { get }
    var composer: DeviceTransferDataComposer { get }
    var parser: DeviceTransferDataParser { get }
    var connectionCommand: DeviceTransferCommand? { get }
    
    func start()
    func stop()
    func send(data: Data, completion: (() -> Void)?)
    
}
