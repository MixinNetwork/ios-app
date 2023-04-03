import Foundation
import zlib

struct GzipError: Swift.Error {
    
    let code: Int32
    let message: String?
    
    init(status: Int32, message: UnsafePointer<CChar>?) {
        self.code = status
        if let message, let string = String(validatingUTF8: message) {
            self.message = string
        } else {
            self.message = nil
        }
    }
    
}

extension Data {
    
    private enum DataSize {
        static let chunk = 1 << 14
        static let stream = MemoryLayout<z_stream>.size
    }
    
    var isGzipped: Bool {
        starts(with: [0x1f, 0x8b])
    }
    
    func gzipped() throws -> Data {
        guard !isEmpty else {
            return Data()
        }
        
        var stream = z_stream()
        var status: Int32
        status = deflateInit2_(&stream,
                               Z_DEFAULT_COMPRESSION,
                               Z_DEFLATED,
                               MAX_WBITS + 16,
                               MAX_MEM_LEVEL,
                               Z_DEFAULT_STRATEGY,
                               ZLIB_VERSION,
                               Int32(DataSize.stream))
        guard status == Z_OK else {
            throw GzipError(status: status, message: stream.msg)
        }
        
        var data = Data(capacity: DataSize.chunk)
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += DataSize.chunk
            }
            let inputCount = self.count
            let outputCount = data.count
            self.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: input.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
                stream.avail_in = uint(inputCount) - uInt(stream.total_in)
                data.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
                    stream.next_out = output.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
                    status = deflate(&stream, Z_FINISH)
                    stream.next_out = nil
                }
                stream.next_in = nil
            }
            
        } while stream.avail_out == 0
        
        guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
            throw GzipError(status: status, message: stream.msg)
        }
        data.count = Int(stream.total_out)
        return data
    }
    
    func gunzipped() throws -> Data {
        guard !isEmpty else {
            return Data()
        }
        
        var stream = z_stream()
        var status: Int32
        status = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, Int32(DataSize.stream))
        guard status == Z_OK else {
            throw GzipError(status: status, message: stream.msg)
        }
        
        var data = Data(capacity: self.count * 2)
        repeat {
            if Int(stream.total_out) >= data.count {
                data.count += self.count / 2
            }
            let inputCount = self.count
            let outputCount = data.count
            self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
                stream.avail_in = uint(inputCount) - uInt(stream.total_in)
                data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
                    stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(outputCount) - uInt(stream.total_out)
                    
                    status = inflate(&stream, Z_SYNC_FLUSH)
                    
                    stream.next_out = nil
                }
                stream.next_in = nil
            }
            
        } while status == Z_OK
        
        guard inflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
            throw GzipError(status: status, message: stream.msg)
        }
        data.count = Int(stream.total_out)
        return data
    }
    
}
