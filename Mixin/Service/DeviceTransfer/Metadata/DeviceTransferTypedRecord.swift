import Foundation
import MixinServices

final class DeviceTransferTypedRecord<Record: DeviceTransferRecord>: Codable {
    
    let type: DeviceTransferRecordType
    let data: Record
    
    init(type: DeviceTransferRecordType, data: Record) {
        self.type = type
        self.data = data
    }
    
}
