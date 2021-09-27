#ifndef MXSAESCryptorError_h
#define MXSAESCryptorError_h

#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const NSErrorDomain MXSAESCryptorErrorDomain NS_SWIFT_NAME(AESCryptorErrorDomain);

typedef NS_CLOSED_ENUM(NSUInteger, MXSAESCryptorErrorCode) {
    MXSAESCryptorErrorCodeBadInput,
    MXSAESCryptorErrorCodeCreateCryptor,
    MXSAESCryptorErrorCodeInitializeCryptor,
    MXSAESCryptorErrorCodeAllocateOutput,
    MXSAESCryptorErrorCodeUpdation,
    MXSAESCryptorErrorCodeFinalization,
    MXSAESCryptorErrorCodeGetTag,
    MXSAESCryptorErrorCodeSetTag,
} NS_SWIFT_NAME(AESCryptorError);

#endif /* MXSAESCryptorError_h */
