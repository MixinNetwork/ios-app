#import <CommonCrypto/CommonCrypto.h>
#import "MXSAESCryptor.h"
#import "MXSAESCryptorError.h"

@implementation MXSAESCryptor

+ (NSData * _Nullable)encrypt:(NSData *)plainData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                      padding:(MXSAESCryptorPadding)padding
                        error:(NSError * _Nullable *)outError {
    CCCryptorStatus status = kCCSuccess;
    
    CCOptions options;
    switch (padding) {
        case MXSAESCryptorPaddingPKCS7:
            options = kCCOptionPKCS7Padding;
            break;
        case MXSAESCryptorPaddingNone:
            options = 0;
            break;
    }
    
    CCCryptorRef cryptor = nil;
    status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, options, key.bytes, key.length, iv.bytes, &cryptor);
    if (status != kCCSuccess) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeCreateCryptor
                                        userInfo:@{@"status" : @(status)}];
        }
        return nil;
    }
    
    size_t outputLength = CCCryptorGetOutputLength(cryptor, plainData.length, true);
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
    status = CCCryptorUpdate(cryptor, plainData.bytes, plainData.length, output, outputLength, &dataOutMoved);
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
