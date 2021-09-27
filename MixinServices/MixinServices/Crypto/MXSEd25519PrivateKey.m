#import "MXSEd25519PrivateKey.h"
#import "MXSEd25519PublicKeyInternal.h"
#import <openssl/curve25519.h>
#import <openssl/rand.h>
#import <openssl/sha.h>

static const size_t seedLength = 32;

NS_INLINE NSData* ConvertEd25519ToX25519(uint8_t *seed);

@implementation MXSEd25519PrivateKey {
    NSData *_seed;
    MXSEd25519PublicKey *_publicKey;
    uint8_t _privateKey[ED25519_PRIVATE_KEY_LEN];
    NSData *_x25519;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        uint8_t *seed = malloc(seedLength);
        RAND_bytes(seed, seedLength);
        _seed = [NSData dataWithBytesNoCopy:seed
                                     length:seedLength
                               freeWhenDone:YES];
        
        uint8_t *publicKey = malloc(ED25519_PUBLIC_KEY_LEN);
        ED25519_keypair_from_seed(publicKey, _privateKey, seed);
        _publicKey = [[MXSEd25519PublicKey alloc] initWithBytesNoCopy:publicKey
                                                               length:ED25519_PUBLIC_KEY_LEN
                                                         freeWhenDone:YES];
        if (!publicKey) {
            [NSException raise:@"InvalidPublicKeyException"
                        format:@"MXSEd25519PublicKey fails to initialize"];
        }
        
        _x25519 = ConvertEd25519ToX25519(seed);
    }
    return self;
}

- (nullable instancetype)initWithRFC8032Representation:(NSData *)seed {
    if (seed.length != seedLength) {
        return nil;
    }
    self = [super init];
    if (self) {
        uint8_t *publicKey = malloc(ED25519_PUBLIC_KEY_LEN);
        ED25519_keypair_from_seed(publicKey, _privateKey, seed.bytes);
        _publicKey = [[MXSEd25519PublicKey alloc] initWithBytesNoCopy:publicKey
                                                               length:ED25519_PUBLIC_KEY_LEN
                                                         freeWhenDone:YES];
        if (!publicKey) {
            return nil;
        }
        
        _seed = [seed copy];
        _x25519 = ConvertEd25519ToX25519(seed.bytes);
    }
    return self;
}

- (NSString *)description {
    NSMutableString *desc = [@"MXSEd25519PrivateKey <seed: " mutableCopy];
    [desc appendString:[self.rfc8032Representation base64EncodedStringWithOptions:0]];
    [desc appendString:@", public key: "];
    [desc appendString:[self.publicKey.rawRepresentation base64EncodedStringWithOptions:0]];
    [desc appendString:@">\n"];
    return [desc copy];
}

- (MXSEd25519PublicKey *)publicKey {
    return _publicKey;
}

- (NSData *)rfc8032Representation {
    return _seed;
}

- (NSData *)x25519Representation {
    return _x25519;
}

- (NSData * _Nullable)signatureForData:(NSData *)data {
    uint8_t *sig = malloc(ED25519_SIGNATURE_LEN);
    int result = ED25519_sign(sig, data.bytes, data.length, _privateKey);
    if (result == 1) {
        return [NSData dataWithBytesNoCopy:sig
                                    length:ED25519_SIGNATURE_LEN
                              freeWhenDone:YES];
    } else {
        free(sig);
        return nil;
    }
}

NS_INLINE NSData* ConvertEd25519ToX25519(uint8_t *seed) {
    unsigned char *hash = malloc(SHA512_DIGEST_LENGTH);
    SHA512(seed, seedLength, hash);
    hash[0] &= 248;
    hash[31] &= 127;
    hash[31] |= 64;
    return [NSData dataWithBytesNoCopy:hash length:seedLength freeWhenDone:YES];
}

@end
