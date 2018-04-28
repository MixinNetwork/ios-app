//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "Cryptography.h"
#import "NSData+OWSConstantTimeCompare.h"
#import "NSData+Base64.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import "OWSError.h"

#define HMAC256_KEY_LENGTH 32
#define HMAC256_OUTPUT_LENGTH 32
#define AES_CBC_IV_LENGTH 16
#define AES_KEY_SIZE 32

NS_ASSUME_NONNULL_BEGIN

const NSUInteger kAES256_KeyByteLength = 32;

@implementation OWSAES256Key

+ (nullable instancetype)keyWithData:(NSData *)data
{
    if (data.length != kAES256_KeyByteLength) {
        //OWSFail(@"Invalid key length for AES128: %lu", (unsigned long)data.length);
        return nil;
    }

    return [[self alloc] initWithData:data];
}

+ (instancetype)generateRandomKey
{
    return [self new];
}

- (instancetype)init
{
    return [self initWithData:[Cryptography generateRandomBytes:kAES256_KeyByteLength]];
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (!self) {
        return self;
    }

    _keyData = data;

    return self;
}

#pragma mark - SecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (!self) {
        return self;
    }

    NSData *keyData = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"keyData"];
    if (keyData.length != kAES256_KeyByteLength) {
        //OWSFail(@"Invalid key length: %lu", (unsigned long)keyData.length);
        return nil;
    }

    _keyData = keyData;

    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_keyData forKey:@"keyData"];
}

@end

@implementation Cryptography

+ (NSData *)generateRandomBytes:(NSUInteger)numberBytes
{
    /* used to generate db master key, and to generate signaling key, both at install */
    NSMutableData* randomBytes = [NSMutableData dataWithLength:numberBytes];
    int err = 0;
    err = SecRandomCopyBytes(kSecRandomDefault,numberBytes,[randomBytes mutableBytes]);
    if(err != noErr && [randomBytes length] != numberBytes) {
        @throw [NSException exceptionWithName:@"random problem" reason:@"problem generating the random " userInfo:nil];
    }
    return [NSData dataWithData:randomBytes];
}

#pragma mark SHA1

+ (NSString *)truncatedSHA1Base64EncodedWithoutPadding:(NSString *)string {
    /* used by TSContactManager to send hashed/truncated contact list to server */
    NSMutableData *hashData = [NSMutableData dataWithLength:20];

    CC_SHA1([string dataUsingEncoding:NSUTF8StringEncoding].bytes,
            (unsigned int)[string dataUsingEncoding:NSUTF8StringEncoding].length,
            hashData.mutableBytes);

    NSData *truncatedData = [hashData subdataWithRange:NSMakeRange(0, 10)];

    return [[truncatedData base64EncodedString] stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

+ (NSString *)computeSHA1DigestForString:(NSString *)input {
    // Here we are taking in our string hash, placing that inside of a C Char Array, then parsing it through the SHA1
    // encryption method.
    const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data     = [NSData dataWithBytes:cstr length:input.length];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (unsigned int)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

#pragma mark SHA256 Digest
+ (NSData *)computeSHA256Digest:(NSData *)data
{
    return [self computeSHA256Digest:(NSData *)data truncatedToBytes:CC_SHA256_DIGEST_LENGTH];
}

+ (NSData *)computeSHA256Digest:(NSData *)data truncatedToBytes:(NSUInteger)truncatedBytes
{
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (unsigned int)data.length, digest);
    return
    [[NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH] subdataWithRange:NSMakeRange(0, truncatedBytes)];
}


#pragma mark HMAC/SHA256
+ (NSData *)computeSHA256HMAC:(NSData *)dataToHMAC withHMACKey:(NSData *)HMACKey {
    uint8_t ourHmac[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA256, [HMACKey bytes], [HMACKey length], [dataToHMAC bytes], [dataToHMAC length], ourHmac);
    return [NSData dataWithBytes:ourHmac length:CC_SHA256_DIGEST_LENGTH];
}

+ (NSData *)computeSHA1HMAC:(NSData *)dataToHMAC withHMACKey:(NSData *)HMACKey {
    uint8_t ourHmac[CC_SHA256_DIGEST_LENGTH] = {0};
    CCHmac(kCCHmacAlgSHA1, [HMACKey bytes], [HMACKey length], [dataToHMAC bytes], [dataToHMAC length], ourHmac);
    return [NSData dataWithBytes:ourHmac length:CC_SHA256_DIGEST_LENGTH];
}


+ (NSData *)truncatedSHA1HMAC:(NSData *)dataToHMAC withHMACKey:(NSData *)HMACKey truncation:(NSUInteger)bytes {
    return [[Cryptography computeSHA1HMAC:dataToHMAC withHMACKey:HMACKey] subdataWithRange:NSMakeRange(0, bytes)];
}

+ (NSData *)truncatedSHA256HMAC:(NSData *)dataToHMAC withHMACKey:(NSData *)HMACKey truncation:(NSUInteger)bytes {
    return [[Cryptography computeSHA256HMAC:dataToHMAC withHMACKey:HMACKey] subdataWithRange:NSMakeRange(0, bytes)];
}


#pragma mark AES CBC Mode

/**
 * AES256 CBC encrypt then mac. Used to decrypt both signal messages and attachment blobs
 *
 * @return decrypted data or nil if hmac invalid/decryption fails
 */
+ (NSData *)decryptCBCMode:(NSData *)dataToDecrypt
                       key:(NSData *)key
                        IV:(NSData *)iv
                   version:(nullable NSData *)version
                   HMACKey:(NSData *)hmacKey
                  HMACType:(TSMACType)hmacType
              matchingHMAC:(NSData *)hmac
                    digest:(nullable NSData *)digest
{
    // Verify hmac of: version? || iv || encrypted data
    NSMutableData *dataToAuth = [NSMutableData data];
    if (version != nil) {
        [dataToAuth appendData:version];
    }

    [dataToAuth appendData:iv];
    [dataToAuth appendData:dataToDecrypt];

    NSData *ourHmacData;

    if (hmacType == TSHMACSHA1Truncated10Bytes) {
        ourHmacData = [Cryptography truncatedSHA1HMAC:dataToAuth withHMACKey:hmacKey truncation:10];
    } else if (hmacType == TSHMACSHA256Truncated10Bytes) {
        ourHmacData = [Cryptography truncatedSHA256HMAC:dataToAuth withHMACKey:hmacKey truncation:10];
    } else if (hmacType == TSHMACSHA256AttachementType) {
        ourHmacData =
        [Cryptography truncatedSHA256HMAC:dataToAuth withHMACKey:hmacKey truncation:HMAC256_OUTPUT_LENGTH];
    }

    if (hmac == nil || ![ourHmacData ows_constantTimeIsEqualToData:hmac]) {
//        DDLogError(@"%@ %s Bad HMAC on decrypting payload. Their MAC: %@, our MAC: %@",
//                   self.logTag,
//                   __PRETTY_FUNCTION__,
//                   hmac,
//                   ourHmacData);
        return nil;
    }

    // Optionally verify digest of: version? || iv || encrypted data || hmac
    if (digest) {
        //DDLogDebug(@"%@ %s verifying their digest: %@", self.logTag, __PRETTY_FUNCTION__, digest);
        [dataToAuth appendData:ourHmacData];
        NSData *ourDigest = [Cryptography computeSHA256Digest:dataToAuth];
        if (!ourDigest || ![ourDigest ows_constantTimeIsEqualToData:digest]) {
//            DDLogWarn(@"%@ Bad digest on decrypting payload. Their digest: %@, our digest: %@",
//                      self.logTag,
//                      digest,
//                      ourDigest);
            return nil;
        }
    }

    // decrypt
    size_t bufferSize = [dataToDecrypt length] + kCCBlockSizeAES128;
    void *buffer      = malloc(bufferSize);

    if (buffer == NULL) {
        //DDLogError(@"%@ Failed to allocate memory.", self.logTag);
        return nil;
    }

    size_t bytesDecrypted       = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          [key bytes],
                                          [key length],
                                          [iv bytes],
                                          [dataToDecrypt bytes],
                                          [dataToDecrypt length],
                                          buffer,
                                          bufferSize,
                                          &bytesDecrypted);
    if (cryptStatus == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:bytesDecrypted freeWhenDone:YES];
    } else {
        //DDLogError(@"%@ Failed CBC decryption", self.logTag);
        free(buffer);
    }

    return nil;
}

#pragma mark methods which use AES CBC
+ (NSData *)decryptAppleMessagePayload:(NSData *)payload withSignalingKey:(NSString *)signalingKeyString {
    assert(payload);
    assert(signalingKeyString);

    unsigned char version[1];
    unsigned char iv[16];
    NSUInteger ciphertext_length = ([payload length] - 10 - 17) * sizeof(char);
    unsigned char *ciphertext    = (unsigned char *)malloc(ciphertext_length);
    unsigned char mac[10];
    [payload getBytes:version range:NSMakeRange(0, 1)];
    [payload getBytes:iv range:NSMakeRange(1, 16)];
    [payload getBytes:ciphertext range:NSMakeRange(17, [payload length] - 10 - 17)];
    [payload getBytes:mac range:NSMakeRange([payload length] - 10, 10)];

    NSData *signalingKey                = [NSData dataFromBase64String:signalingKeyString];
    NSData *signalingKeyAESKeyMaterial  = [signalingKey subdataWithRange:NSMakeRange(0, 32)];
    NSData *signalingKeyHMACKeyMaterial = [signalingKey subdataWithRange:NSMakeRange(32, 20)];
    return
    [Cryptography decryptCBCMode:[NSData dataWithBytesNoCopy:ciphertext length:ciphertext_length freeWhenDone:YES]
                             key:signalingKeyAESKeyMaterial
                              IV:[NSData dataWithBytes:iv length:16]
                         version:[NSData dataWithBytes:version length:1]
                         HMACKey:signalingKeyHMACKeyMaterial
                        HMACType:TSHMACSHA256Truncated10Bytes
                    matchingHMAC:[NSData dataWithBytes:mac length:10]
                          digest:nil];
}

+ (NSData *)decryptAttachment:(NSData *)dataToDecrypt
                      withKey:(NSData *)key
                       digest:(nullable NSData *)digest
                 unpaddedSize:(UInt32)unpaddedSize
                        error:(NSError **)error;
{
    if (digest.length <= 0) {
        // This *could* happen with sufficiently outdated clients.
        //DDLogError(@"%@ Refusing to decrypt attachment without a digest.", self.logTag);
        *error = OWSErrorWithCodeDescription(OWSErrorCodeFailedToDecryptMessage,
                                             NSLocalizedString(@"ERROR_MESSAGE_ATTACHMENT_FROM_OLD_CLIENT",
                                                               @"Error message when unable to receive an attachment because the sending client is too old."));
        return nil;
    }

    if (([dataToDecrypt length] < AES_CBC_IV_LENGTH + HMAC256_OUTPUT_LENGTH) ||
        ([key length] < AES_KEY_SIZE + HMAC256_KEY_LENGTH)) {
        //DDLogError(@"%@ Message shorter than crypto overhead!", self.logTag);
        *error = OWSErrorWithCodeDescription(
                                             OWSErrorCodeFailedToDecryptMessage, NSLocalizedString(@"ERROR_MESSAGE_INVALID_MESSAGE", @""));
        return nil;
    }

    // key: 32 byte AES key || 32 byte Hmac-SHA256 key.
    NSData *encryptionKey = [key subdataWithRange:NSMakeRange(0, AES_KEY_SIZE)];
    NSData *hmacKey       = [key subdataWithRange:NSMakeRange(AES_KEY_SIZE, HMAC256_KEY_LENGTH)];

    // dataToDecrypt: IV || Ciphertext || truncated MAC(IV||Ciphertext)
    NSData *iv                  = [dataToDecrypt subdataWithRange:NSMakeRange(0, AES_CBC_IV_LENGTH)];
    NSData *encryptedAttachment = [dataToDecrypt
                                   subdataWithRange:NSMakeRange(AES_CBC_IV_LENGTH,
                                                                [dataToDecrypt length] - AES_CBC_IV_LENGTH - HMAC256_OUTPUT_LENGTH)];
    NSData *hmac = [dataToDecrypt
                    subdataWithRange:NSMakeRange([dataToDecrypt length] - HMAC256_OUTPUT_LENGTH, HMAC256_OUTPUT_LENGTH)];

    NSData *paddedPlainText = [Cryptography decryptCBCMode:encryptedAttachment
                                                       key:encryptionKey
                                                        IV:iv
                                                   version:nil
                                                   HMACKey:hmacKey
                                                  HMACType:TSHMACSHA256AttachementType
                                              matchingHMAC:hmac
                                                    digest:digest];
    if (unpaddedSize == 0) {
        // Work around for legacy iOS client's which weren't setting padding size.
        // Since we know those clients pre-date attachment padding we return the entire data.
        //DDLogWarn(@"%@ Decrypted attachment with unspecified size.", self.logTag);
        return paddedPlainText;
    } else {
        if (unpaddedSize > paddedPlainText.length) {
            *error = OWSErrorWithCodeDescription(
                                                 OWSErrorCodeFailedToDecryptMessage, NSLocalizedString(@"ERROR_MESSAGE_INVALID_MESSAGE", @""));
            return nil;
        }

        if (unpaddedSize == paddedPlainText.length) {
            //DDLogInfo(@"%@ decrypted unpadded attachment.", self.logTag);
            return [paddedPlainText copy];
        } else {
//            unsigned long paddingSize = paddedPlainText.length - unpaddedSize;
//            DDLogInfo(@"%@ decrypted padded attachment with unpaddedSize: %u, paddingSize: %lu",
//                      self.logTag,
//                      unpaddedSize,
//                      paddingSize);
            return [paddedPlainText subdataWithRange:NSMakeRange(0, unpaddedSize)];
        }
    }
}

+ (unsigned long)paddedSize:(unsigned long)unpaddedSize
{
    // Don't enable this until clients are sufficiently rolled out.
    BOOL shouldPad = NO;
    if (shouldPad) {
        // Note: This just rounds up to the nearsest power of two,
        // but the actual padding scheme is TBD
        return pow(2, ceil( log2( unpaddedSize )));
    } else {
        return unpaddedSize;
    }
}

+ (NSData *)encryptAttachmentData:(NSData *)attachmentData
                           outKey:(NSData * _Nullable __autoreleasing * _Nullable)outKey
                        outDigest:(NSData * _Nullable __autoreleasing * _Nullable)outDigest
{
    NSData *iv            = [Cryptography generateRandomBytes:AES_CBC_IV_LENGTH];
    NSData *encryptionKey = [Cryptography generateRandomBytes:AES_KEY_SIZE];
    NSData *hmacKey       = [Cryptography generateRandomBytes:HMAC256_KEY_LENGTH];

    // The concatenated key for storage
    NSMutableData *attachmentKey = [NSMutableData data];
    [attachmentKey appendData:encryptionKey];
    [attachmentKey appendData:hmacKey];
    *outKey = [attachmentKey copy];

    // Apply any padding
    unsigned long desiredSize = [self paddedSize:attachmentData.length];
    NSMutableData *paddedAttachmentData = [attachmentData mutableCopy];
    paddedAttachmentData.length = desiredSize;

    // Encrypt
    size_t bufferSize = [paddedAttachmentData length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    if (buffer == NULL) {
        //DDLogError(@"%@ Failed to allocate memory.", self.logTag);
        return nil;
    }

    size_t bytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          [encryptionKey bytes],
                                          [encryptionKey length],
                                          [iv bytes],
                                          [paddedAttachmentData bytes],
                                          [paddedAttachmentData length],
                                          buffer,
                                          bufferSize,
                                          &bytesEncrypted);

    if (cryptStatus != kCCSuccess) {
//        DDLogError(@"%@ %s CCCrypt failed with status: %d", self.logTag, __PRETTY_FUNCTION__, (int32_t)cryptStatus);
        free(buffer);
        return nil;
    }

    NSData *cipherText = [NSData dataWithBytesNoCopy:buffer length:bytesEncrypted freeWhenDone:YES];

    NSMutableData *encryptedPaddedData = [NSMutableData data];
    [encryptedPaddedData appendData:iv];
    [encryptedPaddedData appendData:cipherText];

    // compute hmac of: iv || encrypted data
    NSData *hmac =
    [Cryptography truncatedSHA256HMAC:encryptedPaddedData withHMACKey:hmacKey truncation:HMAC256_OUTPUT_LENGTH];
    //DDLogVerbose(@"%@ computed hmac: %@", self.logTag, hmac);

    [encryptedPaddedData appendData:hmac];

    // compute digest of: iv || encrypted data || hmac
    *outDigest = [self computeSHA256Digest:encryptedPaddedData];
    //DDLogVerbose(@"%@ computed digest: %@", self.logTag, *outDigest);

    return [encryptedPaddedData copy];
}

@end

NS_ASSUME_NONNULL_END
