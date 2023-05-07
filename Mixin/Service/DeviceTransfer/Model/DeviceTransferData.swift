import Foundation
import MixinServices

let maxMessageDeviceTransferDataSize = 500 * bytesPerKiloByte

class DeviceTransferData<TransferData>: Codable where TransferData: Codable {
    
    let type: DeviceTransferMessageType
    let data: TransferData
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(type: DeviceTransferMessageType, data: TransferData) {
        self.type = type
        self.data = data
    }
    
}
