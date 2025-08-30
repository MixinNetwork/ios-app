import Foundation
import XKCP_FIPS202

public enum SHA3_256 {
    
    private static let outputCount = 32
    
    public static func hash(data: Data) -> Data? {
        let output = malloc(outputCount)!
        let result = data.withUnsafeBytes { buffer in
            XKCP_FIPS202.SHA3_256(output, buffer.baseAddress, buffer.count)
        }
        if result == 0 {
            return Data(bytesNoCopy: output, count: outputCount, deallocator: .free)
        } else {
            free(output)
            return nil
        }
    }
    
}
