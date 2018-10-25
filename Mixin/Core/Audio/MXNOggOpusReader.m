
#import "MXNOggOpusReader.h"
#import "MXNOggOpusError.h"
#import "opusfile.h"

@implementation MXNOggOpusReader {
    NSString *_path;
    OggOpusFile *_file;
    NSMutableData *_outputBuffer;
}

+ (nullable instancetype)readerWithFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError {
    return [[MXNOggOpusReader alloc] initWithFileAtPath:path error:outError];
}

- (nullable instancetype)initWithFileAtPath:(NSString *)path error:(NSError * _Nullable *)outError {
    self = [super init];
    if (self) {
        _path = path;
        int result = OPUS_OK;
        _file = op_open_file([_path UTF8String], &result);
        if (result != OPUS_OK) {
            if (outError) {
                *outError = ErrorWithCodeAndOpusErrorCode(result, result);
            }
            return nil;
        }
    }
    return self;
}

- (void)close {
    op_free(_file);
    _file = nil;
}

- (NSData * _Nullable)pcmDataWithMaxLength:(NSUInteger)maxLength
                                     error:(NSError * _Nullable *)outError {
    NSParameterAssert((maxLength / 2) <= INT_MAX);
    if (!_outputBuffer) {
        _outputBuffer = [NSMutableData dataWithLength:maxLength];
    }
    if (_outputBuffer.length < maxLength) {
        _outputBuffer.length = maxLength;
    }
    int result = op_read(_file, (opus_int16 *)_outputBuffer.mutableBytes, (int)(maxLength / 2), NULL);
    int bytesRead = 0;
    if (result < 0) {
        if (outError) {
            *outError = ErrorWithCodeAndOpusErrorCode(MXNOggOpusErrorCodeRead, result);
        }
        return nil;
    } else {
        bytesRead = result * 2;
    }
    return [_outputBuffer subdataWithRange:NSMakeRange(0, bytesRead)];
}

- (void)seekToZero {
    op_raw_seek(_file, 0);
}

@end
