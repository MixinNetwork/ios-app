import Foundation

extension UUID: RawBufferInitializable {
    
    public static var bufferCount: Int {
        16
    }
    
    public init?(_ buffer: UnsafeMutableRawBufferPointer) {
        assert(buffer.count >= Self.bufferCount)
        
        // https://forums.swift.org/t/guarantee-in-memory-tuple-layout-or-dont/40122
        // Tuples have always had their own guarantee: if all the elements are the same type,
        // they will be laid out in order by stride (size rounded up to alignment), just like
        // a fixed-sized array in C.
        let uuid = buffer.load(as: uuid_t.self)
        
        self = UUID(uuid: uuid)
    }
    
}
