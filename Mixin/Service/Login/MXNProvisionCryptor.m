#import "MXNProvisionCryptor.h"
#import "Mixin-Swift.h"
#import <libsignal_protocol_c/signal_protocol.h>
#import <CommonCrypto/CommonCrypto.h>

const size_t ivLength = 16;
const size_t messageEncryptKeyLength = 32;
const size_t hmacKeyLength = 32;
const size_t versionLength = sizeof(uint8_t);
const uint8_t version = 1;

@implementation MXNProvisionCryptor {
    signal_context *_context;
    ec_public_key *_remotePublicKey;
}

- (instancetype)initWithSignalContext:(signal_context *)context
               base64EncodedPublicKey:(NSString *)publicKey {
    self = [super init];
    if (self) {
        _context = context;
        NSData *keyData = [[NSData alloc] initWithBase64EncodedString:publicKey options:0];
        curve_decode_point(&_remotePublicKey, keyData.bytes, keyData.length, _context);
    }
    return self;
}

- (void)dealloc {
    SIGNAL_UNREF(_remotePublicKey);
}

- (NSData * _Nullable)encryptedDataFrom:(ProvisionMessage *)message {
    NSData *messageJSONData = [message jsonData];
    if (!messageJSONData) {
        return nil;
    }
    
    NSData *result = nil;
    int status = 0;
    
    ec_key_pair *keyPair = nil;
    uint8_t *sharedSecret = nil;
    hkdf_context *hkdf = nil;
    uint8_t *derivedSecret = nil;
    void *iv = nil;
    
    {
        status = curve_generate_key_pair(_context, &keyPair);
        if (status != 0) {
            goto complete;
        }
        
        ec_public_key *localPublicKey = ec_key_pair_get_public(keyPair);
        ec_private_key *localPrivateKey = ec_key_pair_get_private(keyPair);
        
        int sharedSecretLength = curve_calculate_agreement(&sharedSecret, _remotePublicKey, localPrivateKey);
        if (sharedSecretLength <= 0) {
            goto complete;
        }
        
        status = hkdf_create(&hkdf, 3, _context);
        if (status != 0) {
            goto complete;
        }
        
        NSData *salt = [NSMutableData dataWithLength:32];
        NSData *info = [@"Mixin Provisioning Message" dataUsingEncoding:NSUTF8StringEncoding];
        
        ssize_t derivedSecretLength = hkdf_derive_secrets(hkdf, &derivedSecret, sharedSecret, sharedSecretLength, salt.bytes, salt.length, info.bytes, info.length, messageEncryptKeyLength + hmacKeyLength);
        if (derivedSecretLength < 0) {
            goto complete;
        }
        uint8_t *messageEncryptKey = derivedSecret;
        uint8_t *hmacKey = derivedSecret + messageEncryptKeyLength;
        
        iv = malloc(ivLength);
        status = SecRandomCopyBytes(kSecRandomDefault, ivLength, iv);
        if (status != errSecSuccess) {
            goto complete;
        }
        
        CCCryptorRef cryptor = nil;
        CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding, messageEncryptKey, messageEncryptKeyLength, iv, &cryptor);
        size_t encryptedMessageLength = CCCryptorGetOutputLength(cryptor, messageJSONData.length, true);
        
        NSUInteger bodyLength = versionLength + ivLength + encryptedMessageLength + CC_SHA256_DIGEST_LENGTH;
        NSMutableData *body = [NSMutableData dataWithCapacity:bodyLength];
        [body appendBytes:&version length:versionLength];
        [body appendBytes:iv length:ivLength];
        
        void *encryptedMessage = malloc(encryptedMessageLength);
        size_t dataOutMoved = 0;
        CCCryptorUpdate(cryptor, messageJSONData.bytes, messageJSONData.length, encryptedMessage, encryptedMessageLength, &dataOutMoved);
        CCCryptorFinal(cryptor, encryptedMessage + dataOutMoved, encryptedMessageLength - dataOutMoved, &dataOutMoved);
        [body appendBytes:encryptedMessage length:encryptedMessageLength];
        free(encryptedMessage);
        CCCryptorRelease(cryptor);

        void *hmac = malloc(CC_SHA256_DIGEST_LENGTH);
        CCHmac(kCCHmacAlgSHA256, hmacKey, hmacKeyLength, body.bytes, versionLength + ivLength + encryptedMessageLength, hmac);
        [body appendBytes:hmac length:CC_SHA256_DIGEST_LENGTH];
        free(hmac);
        
        signal_buffer *buffer = nil;
        status = ec_public_key_serialize(&buffer, localPublicKey);
        if (status != 0) {
            goto complete;
        }
        NSData *serializedPublicKey = [NSData dataWithBytes:signal_buffer_data(buffer)
                                                     length:signal_buffer_len(buffer)];
        signal_buffer_free(buffer);
        
        NSDictionary *envelope = @{@"public_key": [serializedPublicKey base64EncodedStringWithOptions:0],
                                   @"body": [body base64EncodedStringWithOptions:0]};
        result = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:nil];
    }
    
complete:
    SIGNAL_UNREF(keyPair);
    free(sharedSecret);
    SIGNAL_UNREF(hkdf);
    free(derivedSecret);
    free(iv);
    return result;
}

@end
