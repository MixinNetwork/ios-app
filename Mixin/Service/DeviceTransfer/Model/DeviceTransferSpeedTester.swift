import Foundation
import MixinServices

protocol DeviceTransferSpeedTesterDelegate: AnyObject {
    
    func deviceTransferSpeedTester(_ tester: DeviceTransferSpeedTester, didUpdate speed: String)
    
}

class DeviceTransferSpeedTester {
    
    weak var delegate: DeviceTransferSpeedTesterDelegate?
    
    private weak var timer: Timer?
    private var totalBytesSent: Int64 = 0
    
    func send(data: Data) {
        totalBytesSent += Int64(data.count)
        startTimer()
    }
    
    func startTimer() {
        guard timer == nil else {
            return
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (_) in
            guard let self = self else {
                return
            }
            let speed = Double(self.totalBytesSent) / 1024.0 / 1024.0
            self.totalBytesSent = 0
            let formattedSpeed = String(format: "%.1fMB/s", speed)
            self.delegate?.deviceTransferSpeedTester(self, didUpdate: "\(formattedSpeed)")
            Logger.general.debug(category: "DeviceTransferSpeedTester", message: "Speed: \(formattedSpeed)")
        })
        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        totalBytesSent = 0
    }
    
}
