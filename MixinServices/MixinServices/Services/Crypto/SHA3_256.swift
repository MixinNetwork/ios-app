import Foundation
import XKCP_SimpleFIPS202

enum SHA3_256 {
    
    private static let outputCount = 32
    
    static func hash(data: Data) -> Data? {
        let output = malloc(outputCount)!
        let result = data.withUnsafeUInt8Pointer { input in
            XKCP_SimpleFIPS202.SHA3_256(output, input, data.count)
        }
        if result == 0 {
            return Data(bytesNoCopy: output, count: outputCount, deallocator: .free)
        } else {
            free(output)
            return nil
        }
    }
    
}
