import Foundation
import Combine
import MixinServices

protocol DeviceTransferServiceProvidable {
    
    var displayState: DeviceTransferDisplayState { get }
    var composer: DeviceTransferDataComposer { get }
    var parser: DeviceTransferDataParser { get }
    var connectionCommand: DeviceTransferCommand? { get }
    var speedTester: DeviceTransferSpeedTester { get }
    
    func start()
    func stop()
    func send(data: Data, completion: (() -> Void)?)
    
}

extension DeviceTransferServiceProvidable {
    
    func startSpeedTester() {
        DispatchQueue.main.async(execute: speedTester.start)
    }

    func stopSpeedTester() {
        DispatchQueue.main.async(execute: speedTester.stop)
    }
    
}
