
#ifndef MXNOggOpusError_h
#define MXNOggOpusError_h

#import <Foundation/Foundation.h>

#define ReturnNilIfOpusError(result, code) if (result != OPUS_OK) { \
                                                if (outError) { \
                                                    *outError = ErrorWithCodeAndOpusErrorCode(code, result); \
                                                } \
                                                return nil; \
                                           }

FOUNDATION_EXTERN const NSErrorDomain MXNOggOpusErrorDomain;

typedef NS_ENUM(NSUInteger, MXNOggOpusErrorCode) {
    MXNOggOpusErrorCodeCreateEncoder,
    MXNOggOpusErrorCodeSetBitrate,
    MXNOggOpusErrorCodeEncodingFailed,
    MXNOggOpusErrorCodeTestFile,
    MXNOggOpusErrorCodeTestOpen,
    MXNOggOpusErrorCodeOpenFile,
    MXNOggOpusErrorCodeRead
};

NS_INLINE NSError* ErrorWithCodeAndOpusErrorCode(MXNOggOpusErrorCode code, int32_t opusCode) {
    return [NSError errorWithDomain:MXNOggOpusErrorDomain
                               code:code
                           userInfo:@{@"opus_code" : @(opusCode)}];
}

#endif /* MXNOggOpusError_h */
