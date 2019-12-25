#import <Foundation/Foundation.h>
#import <libsignal_protocol_c/curve.h>
#import <libsignal_protocol_c/hkdf.h>

NS_ASSUME_NONNULL_BEGIN

@class ProvisionMessage;

@interface MXNProvisionCryptor : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSignalContext:(signal_context *)context
               base64EncodedPublicKey:(NSString *)publicKey NS_SWIFT_NAME(init(signalContext:base64EncodedPublicKey:));

- (NSData * _Nullable)encryptedDataFrom:(ProvisionMessage *)message;

@end

NS_ASSUME_NONNULL_END
