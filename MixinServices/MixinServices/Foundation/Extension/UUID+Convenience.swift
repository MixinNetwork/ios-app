import Foundation

extension UUID {
    
    public var data: Data {
        Data([
            uuid.0,  uuid.1,  uuid.2,  uuid.3,
            uuid.4,  uuid.5,  uuid.6,  uuid.7,
            uuid.8,  uuid.9,  uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15
        ])
    }
    
    public init(data: Data) {
        assert(data.count == 16)
        let uuid: uuid_t = (
            data[data.startIndex],
            data[data.startIndex.advanced(by: 1)],
            data[data.startIndex.advanced(by: 2)],
            data[data.startIndex.advanced(by: 3)],
            data[data.startIndex.advanced(by: 4)],
            data[data.startIndex.advanced(by: 5)],
            data[data.startIndex.advanced(by: 6)],
            data[data.startIndex.advanced(by: 7)],
            data[data.startIndex.advanced(by: 8)],
            data[data.startIndex.advanced(by: 9)],
            data[data.startIndex.advanced(by: 10)],
            data[data.startIndex.advanced(by: 11)],
            data[data.startIndex.advanced(by: 12)],
            data[data.startIndex.advanced(by: 13)],
            data[data.startIndex.advanced(by: 14)],
            data[data.startIndex.advanced(by: 15)]
        )
        self = UUID(uuid: uuid)
    }
    
    public static func isValidUUIDString(_ string: String) -> Bool {
        UUID(uuidString: string) != nil
    }
    
}
