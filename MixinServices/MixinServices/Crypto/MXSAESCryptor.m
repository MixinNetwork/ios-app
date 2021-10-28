#import <CommonCrypto/CommonCrypto.h>
#import "MXSAESCryptor.h"
#import "MXSAESCryptorError.h"

@implementation MXSAESCryptor

NS_INLINE NSData* Crypt(NSData *input, CCOperation op, NSData *key, NSData *iv, CCOptions options, NSError **outError);

+ (NSData * _Nullable)encrypt:(NSData *)plainData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                      padding:(MXSAESCryptorPadding)padding
                        error:(NSError * _Nullable *)outError {
    CCOptions options;
    switch (padding) {
        case MXSAESCryptorPaddingPKCS7:
            options = kCCOptionPKCS7Padding;
            break;
        case MXSAESCryptorPaddingNone:
            if (plainData.length % kCCBlockSizeAES128) {
                if (outError) {
                    *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                                    code:MXSAESCryptorErrorCodeBadInput
                                                userInfo:nil];
                }
                return nil;
            }
            options = 0;
            break;
    }
    return Crypt(plainData, kCCEncrypt, key, iv, options, outError);
}

+ (NSData * _Nullable)decrypt:(NSData *)cipher
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError {
    return Crypt(cipher, kCCDecrypt, key, iv, 0, outError);
}

NS_INLINE NSData* Crypt(NSData *input, CCOperation op, NSData *key, NSData *iv, CCOptions options, NSError **outError) {
    CCCryptorStatus status = kCCSuccess;
    
    CCCryptorRef cryptor = nil;
    status = CCCryptorCreate(op, kCCAlgorithmAES, options, key.bytes, key.length, iv.bytes, &cryptor);
    if (status != kCCSuccess) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeCreateCryptor
                                        userInfo:@{@"status" : @(status)}];
        }
        return nil;
    }
    
    size_t outputLength = CCCryptorGetOutputLength(cryptor, input.length, true);
    void *output = malloc(outputLength);
    if (!output) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeAllocateOutput
                                        userInfo:nil];
        }
        CCCryptorRelease(cryptor);
        return nil;
    }
    
    size_t dataOutMoved = 0;
    status = CCCryptorUpdate(cryptor, input.bytes, input.length, output, outputLength, &dataOutMoved);
    if (status != kCCSuccess) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeUpdation
                                        userInfo:@{@"status" : @(status)}];
        }
        CCCryptorRelease(cryptor);
        free(output);
        return nil;
    }
    
    status = CCCryptorFinal(cryptor, output + dataOutMoved, outputLength - dataOutMoved, &dataOutMoved);
    if (status != kCCSuccess) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeFinalization
                                        userInfo:@{@"status" : @(status)}];
        }
        CCCryptorRelease(cryptor);
        free(output);
        return nil;
    }
    
    CCCryptorRelease(cryptor);
    return [NSData dataWithBytesNoCopy:output length:outputLength freeWhenDone:YES];
}

@end
