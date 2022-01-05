#import "MXSEd25519PublicKey.h"
#import "sodium.h"

@implementation MXSEd25519PublicKey {
    NSData *_raw;
    NSData *_x25519;
}

- (nullable instancetype)initWithBytesNoCopy:(uint8_t *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)b {
    uint8_t *x25519 = malloc(crypto_scalarmult_curve25519_BYTES);
    if (!x25519) {
        if (b) {
            free(bytes);
        }
        return nil;
    }
    
    // OpenSSL is considering adding ed25519 to curve25519 conversion in future
    // Remove libsodium when it happens
    // https://github.com/openssl/openssl/issues/13630
    if (crypto_sign_ed25519_pk_to_curve25519(x25519, bytes) != 0) {
        if (b) {
            free(bytes);
        }
        free(x25519);
        return nil;
    }
    
    self = [super init];
    if (self) {
        _raw = [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:b];
        _x25519 = [NSData dataWithBytesNoCopy:x25519 length:crypto_scalarmult_curve25519_BYTES freeWhenDone:YES];
    }
    return self;
}

- (NSData *)rawRepresentation {
    return _raw;
}

- (NSData *)x25519Representation {
    return _x25519;
}

@end
