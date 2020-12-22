#import "MXSEd25519PrivateKey.h"
#import "MXSEd25519PublicKeyInternal.h"
#include <openssl/curve25519.h>
#include <openssl/rand.h>
#include <openssl/sha.h>

static const int seedLength = 32;

@implementation MXSEd25519PrivateKey {
    uint8_t _seed[seedLength];
    uint8_t _publicKey[ED25519_PUBLIC_KEY_LEN];
    uint8_t _privateKey[ED25519_PRIVATE_KEY_LEN];
}

- (instancetype)initWithRFC8032Representation:(NSData *)seed {
    self = [super init];
    if (self) {
        NSAssert(seed.length == seedLength, @"Invalid seed");
        memcpy(_seed, seed.bytes, seedLength);
        ED25519_keypair_from_seed(_publicKey, _privateKey, _seed);
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        RAND_bytes(_seed, seedLength);
        ED25519_keypair_from_seed(_publicKey, _privateKey, _seed);
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
    return [[MXSEd25519PublicKey alloc] initWithBytes:_publicKey];
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
