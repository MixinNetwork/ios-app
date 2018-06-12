import Foundation

struct Waveform {
    
    static let minCount = 30
    static let maxCount = 60
    
    let values: [UInt8]
    
    init(data: Data, valuesCount: Int) {
        let valuesCount = min(Waveform.maxCount, max(Waveform.minCount, valuesCount))
        var values = [UInt8](repeating: 0, count: valuesCount)
        for (i, value) in data.enumerated() {
            let targetIndex = i * valuesCount / data.count
            values[targetIndex] = max(value, data[i])
        }
        self.values = values
    }
    
}

extension Waveform: Equatable {
    
    static func ==(lhs: Waveform, rhs: Waveform) -> Bool {
        return lhs.values == rhs.values
    }
    
}
