import Foundation

class OggOpusReader {
    
    enum Error: Swift.Error {
        case memoryAllocation
        case openFile(Int32)
        case read(Int32)
    }
    
    private(set) var didReachEnd = false
    
    private let file: OpaquePointer
    
    init(fileAtPath path: String) throws {
        var result: Int32 = 0
        let file = path.withCString { (cPath) -> OpaquePointer? in
            op_open_file(cPath, &result)
        }
        if result == 0, let file = file {
            self.file = file
        } else {
            throw Error.openFile(result)
        }
    }
    
    deinit {
        op_free(file)
    }
    
    func pcmData(maxLength: Int32) throws -> Data {
        guard let buffer = malloc(Int(maxLength)) else {
            throw Error.memoryAllocation
        }
        defer {
            free(buffer)
        }
        
        let output = buffer.assumingMemoryBound(to: opus_int16.self)
        let outputLength = maxLength / 2
        var remainingOutputLength = outputLength
        
        var result: Int32 = 1
        while (result == OP_HOLE || result > 0) && remainingOutputLength > 0 {
            let position = output.advanced(by: Int(outputLength - remainingOutputLength))
            result = op_read(file, position, remainingOutputLength, nil)
            remainingOutputLength -= result
        }
        
        if result < 0 {
            throw Error.read(result)
        } else {
            let count = Int(outputLength - remainingOutputLength) * 2
            if count == 0 {
                didReachEnd = true
                return Data()
            } else {
                return Data(bytes: buffer, count: count)
            }
        }
    }
    
}
