import Foundation
import Combine

protocol DeviceTransferServiceProvidable {
    
    var displayState: DeviceTransferDisplayState { get }
    var composer: DeviceTransferDataComposer { get }
    var parser: DeviceTransferDataParser { get }
    
    func start()
    func stop()
    func send(data: Data, completion: (() -> Void)?)

}
