import Foundation
import MixinServices

protocol DeviceTransferSpeedTesterDelegate: AnyObject {
    
    func deviceTransferSpeedTester(_ tester: DeviceTransferSpeedTester, didUpdate speed: String)
    
}

class DeviceTransferSpeedTester {
    
    weak var delegate: DeviceTransferSpeedTesterDelegate?
    
    private weak var timer: Timer?
    
    @Synchronized(value: 0)
    private var totalBytesTaken: Int64
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    func take(_ data: Data) {
        totalBytesTaken += Int64(data.count)
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        let scheduledTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            guard let self = self else {
                return
            }
            let size = Double(self.totalBytesTaken) / 1024.0 / 1024.0
            self.totalBytesTaken = 0
            let formattedSize = String(format: "%.2f MB", size)
            self.delegate?.deviceTransferSpeedTester(self, didUpdate: "\(formattedSize)/s")
            Logger.general.info(category: "DeviceTransferSpeedTester", message: "TotalBytesTaken: \(formattedSize)")
        })
        timer = scheduledTimer
        RunLoop.current.add(scheduledTimer, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        totalBytesTaken = 0
    }
    
}
