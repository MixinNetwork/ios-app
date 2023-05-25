import Foundation
import libsignal_protocol_c

public struct DeviceTransferKey {
    
    static let rawDataCount = 64
    
    public let raw: Data
    
    public var aes: Data {
        raw[..<firstHMACIndex]
    }
    
    public var hmac: Data {
        raw[firstHMACIndex...]
    }
    
    private let firstHMACIndex: Data.Index
    
    public init?(raw: Data) {
        guard raw.count == Self.rawDataCount else {
            Logger.general.error(category: "DeviceTransferKey", message: "Invalid key data: \(raw.count)")
            return nil
        }
        self.raw = raw
        self.firstHMACIndex = raw.startIndex.advanced(by: 32)
    }
    
    public init() {
        let seed = Data(withNumberOfSecuredRandomBytes: 32)!
        var derived: UnsafeMutablePointer<UInt8>!
        var hkdf: OpaquePointer!
        
        let status = hkdf_create(&hkdf, 3, globalSignalContext)
        assert(status == 0)
        let salt = Data(repeating: 0, count: 32)
        let info = "Mixin Device Transfer".data(using: .utf8)!
        let derivedCount = salt.withUnsafeBytes { salt in
            info.withUnsafeBytes { info in
                seed.withUnsafeBytes { seed in
                    hkdf_derive_secrets(hkdf,
                                        &derived,
                                        seed.baseAddress,
                                        seed.count,
                                        salt.baseAddress,
                                        salt.count,
                                        info.baseAddress,
                                        info.count,
                                        Self.rawDataCount)
                }
            }
        }
        assert(derivedCount == Self.rawDataCount)
        
        let raw = Data(bytesNoCopy: derived, count: Self.rawDataCount, deallocator: .free)
        
        self.raw = raw
        self.firstHMACIndex = raw.startIndex.advanced(by: 32)
    }
    
}
