#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AgreementCalculator)
@interface MXSAgreementCalculator : NSObject

+ (NSData * _Nullable)agreementFromPublicKeyData:(NSData *)publicKeyData
                                  privateKeyData:(NSData *)privateKeyData;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
