import UIKit

struct Waveform {
    
    static let minCount = 30
    static let maxCount: Int = UIScreen.main.bounds.width > 320.1 ? 63 : 50
    static let minDuration = 1
    static let maxDuration = 60
    static let slope = Float(maxCount - minCount) / Float(maxDuration - minDuration)
    static let intercept = Float(minCount) - Float(minDuration) * slope
    
    let values: [UInt8]
    
    init(data: Data?, durationInSeconds duration: Int) {
        let duration = max(Waveform.minDuration, min(Waveform.maxDuration, duration))
        let numberOfValues = Waveform.numberOfValues(forDurationInSeconds: duration)
        var values = [UInt8](repeating: 0, count: numberOfValues)
        if let data = data {
            for (i, value) in data.enumerated() {
                let targetIndex = i * numberOfValues / data.count
                values[targetIndex] = max(value, data[i])
            }
        }
        self.values = values
    }
    
    static func numberOfValues(forDurationInSeconds duration: Int) -> Int {
        return Int(round(Waveform.slope * Float(duration) + Waveform.intercept))
    }
    
}

extension Waveform: Equatable {
    
    static func ==(lhs: Waveform, rhs: Waveform) -> Bool {
        return lhs.values == rhs.values
    }
    
}
