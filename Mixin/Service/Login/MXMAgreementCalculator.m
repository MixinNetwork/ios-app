#import "MXMAgreementCalculator.h"
#import <libsignal_protocol_c/curve.h>
#import <libsignal_protocol_c/curve25519-donna.h>

@implementation MXMAgreementCalculator

+ (NSData * _Nullable)agreementFromPublicKeyData:(NSData *)publicKeyData
                                  privateKeyData:(NSData *)privateKeyData {
    if (publicKeyData.length != DJB_KEY_LEN || privateKeyData.length != DJB_KEY_LEN) {
        return nil;
    }
    
    uint8_t *agreement = malloc(DJB_KEY_LEN);
    if (!agreement) {
        return nil;
    }
    
    int status = curve25519_donna(agreement, privateKeyData.bytes, publicKeyData.bytes);
    
    if (status == 0) {
        NSData *data = [NSData dataWithBytesNoCopy:agreement length:DJB_KEY_LEN];
        return data;
    } else {
        if (agreement) {
            free(agreement);
        }
        return nil;
    }
}

@end
