#import "MXCEd25519PrivateKey.h"
#import "MXCEd25519PublicKeyInternal.h"
#include <openssl/curve25519.h>
#include <openssl/rand.h>
#include <openssl/sha.h>

static const int seedLength = 32;

@implementation MXCEd25519PrivateKey {
    uint8_t _seed[seedLength];
    uint8_t _publicKey[ED25519_PUBLIC_KEY_LEN];
    uint8_t _privateKey[ED25519_PRIVATE_KEY_LEN];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        RAND_bytes(_seed, seedLength);
        ED25519_keypair_from_seed(_publicKey, _privateKey, _seed);
    }
    return self;
}

- (MXCEd25519PublicKey *)publicKey {
    return [[MXCEd25519PublicKey alloc] initWithBytes:_publicKey];
}

- (NSData *)rfc8032Representation {
    return [NSData dataWithBytes:_seed length:seedLength];
}

- (NSData *)x25519Representation {
    unsigned char hash[SHA512_DIGEST_LENGTH];
    SHA512(_seed, seedLength, hash);
    hash[0] &= 248;
    hash[31] &= 127;
    hash[31] |= 64;
    return [NSData dataWithBytes:hash length:seedLength];
}

- (NSData * _Nullable)signatureForData:(NSData *)data {
    uint8_t sig[ED25519_SIGNATURE_LEN];
    int result = ED25519_sign(sig, data.bytes, data.length, _privateKey);
    if (result == 1) {
        return [NSData dataWithBytes:sig length:ED25519_SIGNATURE_LEN];
    } else {
        return nil;
    }
}

@end
