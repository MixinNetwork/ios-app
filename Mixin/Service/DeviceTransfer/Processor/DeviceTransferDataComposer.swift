import Foundation
import MixinServices

class DeviceTransferDataComposer {
    
    func commandData(command: DeviceTransferCommand) -> Data? {
        let transferData = DeviceTransferData(type: .command, data: command)
        if let jsonData = try? JSONEncoder.default.encode(transferData) {
            return composeData(type: .command, data: jsonData)
        } else {
            return nil
        }
    }
    
    func messageData<TransferData>(type: DeviceTransferMessageType, data: TransferData) -> Data? where TransferData: Codable {
        let transferData = DeviceTransferData(type: type, data: data)
        if let jsonData = try? JSONEncoder.default.encode(transferData) {
            return composeData(type: .message, data: jsonData)
        } else {
            return nil
        }
    }
        
    private func composeData(type: DeviceTransferDataType, data: Data) -> Data {
        let typeData = Data([type.rawValue])
        let lengthData = UInt32(data.count).data(endianness: .big)
        let checksum = CRC32.checksum(data: data)
        let checksumData = checksum.data(endianness: .big)
        return typeData + lengthData + data + checksumData
    }
    
}
