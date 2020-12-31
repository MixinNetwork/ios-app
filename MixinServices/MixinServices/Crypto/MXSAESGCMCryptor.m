#import <openssl/evp.h>
#import "MXSAESGCMCryptor.h"
#import "MXSAESCryptorError.h"

// References:
// https://www.openssl.org/docs/man1.0.2/man3/EVP_EncryptInit.html
// https://www.openssl.org/docs/man1.1.1/man3/EVP_EncryptInit.html
// https://wiki.openssl.org/index.php/EVP_Authenticated_Encryption_and_Decryption

@implementation MXSAESGCMCryptor

static const size_t tagLength = 16;

+ (NSInteger)tagLength {
    return tagLength;
}

+ (NSData * _Nullable)encrypt:(NSData *)plainData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(encrypt(_:with:iv:padding:)) {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeCreateCryptor
                                        userInfo:nil];
        }
        return nil;
    }
    
    if (1 != EVP_EncryptInit_ex(ctx, EVP_aes_128_gcm(), NULL, key.bytes, iv.bytes)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeInitializeCryptor
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }
    
    size_t outputLength = plainData.length + tagLength;
    uint8_t *output = malloc(outputLength);
    
    int updateLength;
    if (1 != EVP_EncryptUpdate(ctx, output, &updateLength, plainData.bytes, plainData.length)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeUpdation
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    int finalLength;
    if (1 != EVP_EncryptFinal_ex(ctx, output + updateLength, &finalLength)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeFinalization
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    NSAssert(updateLength + finalLength == plainData.length, @"This is not expected to happen");
    
    int getTag = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, tagLength, output + plainData.length);
    if (!getTag) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeGetTag
                                        userInfo:@{@"get_tag" : @(getTag)}];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    EVP_CIPHER_CTX_free(ctx);
    return [NSData dataWithBytesNoCopy:output length:outputLength freeWhenDone:YES];
}

+ (NSData * _Nullable)decrypt:(NSData *)cipherData
                      withKey:(NSData *)key
                           iv:(NSData *)iv
                        error:(NSError * _Nullable *)outError NS_SWIFT_NAME(decrypt(_:with:iv:)) {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeCreateCryptor
                                        userInfo:nil];
        }
        return nil;
    }
    
    if (!EVP_DecryptInit(ctx, EVP_aes_128_gcm(), key.bytes, iv.bytes)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeInitializeCryptor
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        return nil;
    }
    
    size_t cipherLength = cipherData.length - tagLength;
    uint8_t *output = malloc(cipherLength);
    int updateLength;
    if (!EVP_DecryptUpdate(ctx, output, &updateLength, cipherData.bytes, cipherLength)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeUpdation
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    int setTag = EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, tagLength, cipherData.bytes + cipherLength);
    if (!setTag) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeGetTag
                                        userInfo:@{@"set_tag" : @(setTag)}];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    int finalLength;
    if (!EVP_DecryptFinal_ex(ctx, output + cipherLength, &finalLength)) {
        if (outError) {
            *outError = [NSError errorWithDomain:MXSAESCryptorErrorDomain
                                            code:MXSAESCryptorErrorCodeFinalization
                                        userInfo:nil];
        }
        EVP_CIPHER_CTX_free(ctx);
        free(output);
        return nil;
    }
    
    NSAssert(updateLength + finalLength == cipherLength, @"This is not expected to happen");
    EVP_CIPHER_CTX_free(ctx);
    return [NSData dataWithBytesNoCopy:output length:cipherLength freeWhenDone:YES];
}

@end
