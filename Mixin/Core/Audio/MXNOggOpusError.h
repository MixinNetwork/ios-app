
#ifndef MXNOggOpusError_h
#define MXNOggOpusError_h

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const NSErrorDomain MXNOggOpusErrorDomain;

typedef NS_CLOSED_ENUM(NSUInteger, MXNOggOpusErrorCode) {
    MXNOggOpusErrorCodeCreateEncoder,
    MXNOggOpusErrorCodeSetBitrate,
    MXNOggOpusErrorCodeEncodingFailed,
    MXNOggOpusErrorCodeOpenFile,
    MXNOggOpusErrorCodeRead
};

NS_INLINE NSError* ErrorWithCodeAndOpusErrorCode(MXNOggOpusErrorCode code, int32_t opusCode) {
    return [NSError errorWithDomain:MXNOggOpusErrorDomain
                               code:code
                           userInfo:@{@"opus_code" : @(opusCode)}];
}

#endif /* MXNOggOpusError_h */
