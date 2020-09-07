#ifndef MXMOggOpusError_h
#define MXMOggOpusError_h

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const NSErrorDomain MXMOggOpusErrorDomain;

typedef NS_CLOSED_ENUM(NSUInteger, MXMOggOpusErrorCode) {
    MXMOggOpusErrorCodeCreateEncoder,
    MXMOggOpusErrorCodeSetBitrate,
    MXMOggOpusErrorCodeEncodingFailed,
    MXMOggOpusErrorCodeOpenFile,
    MXMOggOpusErrorCodeRead
} NS_SWIFT_NAME(OggOpusError);

NS_INLINE NSError* ErrorWithCodeAndOpusErrorCode(MXMOggOpusErrorCode code, int32_t opusCode) {
    return [NSError errorWithDomain:MXMOggOpusErrorDomain
                               code:code
                           userInfo:@{@"opus_code" : @(opusCode)}];
}

#endif /* MXMOggOpusError_h */
