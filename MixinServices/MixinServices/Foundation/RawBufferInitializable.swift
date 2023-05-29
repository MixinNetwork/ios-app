import Foundation

public protocol RawBufferInitializable {
    
    static var bufferCount: Int { get }
    
    init?(_ buffer: UnsafeMutableRawBufferPointer)
    
}
