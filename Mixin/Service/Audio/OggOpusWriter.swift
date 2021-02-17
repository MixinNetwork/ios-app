import Foundation

fileprivate let numberOfChannels: Int32 = 1;
fileprivate let outputBitRate: Int32 = 16 * 1024;

class OggOpusWriter {
    
    enum Error: Swift.Error {
        case createComments
        case createEncoder(Int32)
        case setBitrate(Int32)
    }
    
    private let comments: OpaquePointer
    private let encoder: OpaquePointer
    
    init(path: String, inputSampleRate: Int32) throws {
        guard let comments = ope_comments_create() else {
            throw Error.createComments
        }
        
        var result = OPE_OK
        self.encoder = path.withCString { (cPath) -> OpaquePointer in
            ope_encoder_create_file(cPath,
                                    comments,
                                    inputSampleRate,
                                    numberOfChannels,
                                    0,
                                    &result)
        }
        guard result == OPE_OK else {
            ope_comments_destroy(comments)
            throw Error.createEncoder(result)
        }
        
        result = ope_encoder_set_bitrate(encoder, outputBitRate)
        guard result == OPE_OK else {
            ope_encoder_destroy(encoder)
            ope_comments_destroy(comments)
            throw Error.setBitrate(result)
        }
        
        self.comments = comments
    }
    
    func write(pcmData: Data) {
        let numberOfPCMSamples = pcmData.count / 2
        assert(numberOfPCMSamples < Int32.max)
        pcmData.withUnsafeBytes { (buffer) -> Void in
            let pcm = buffer.bindMemory(to: opus_int16.self).baseAddress
            ope_encoder_write(encoder, pcm, Int32(pcmData.count / 2))
        }
    }
    
    func close() {
        ope_encoder_drain(encoder)
        ope_encoder_destroy(encoder)
        ope_comments_destroy(comments)
    }
    
}
