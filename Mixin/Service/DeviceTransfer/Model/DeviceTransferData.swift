import Foundation

let maxMessageDeviceTransferDataSize = 512000 // 500K

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
