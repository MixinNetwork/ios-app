// Objective-C API for talking to mixin/kernel Go package.
//   gobind -lang=objc mixin/kernel
//
// File is generated by gobind. Do not edit.

#ifndef __Kernel_H__
#define __Kernel_H__

@import Foundation;
#include "ref.h"
#include "Universe.objc.h"


@class KernelAddress;
@class KernelTx;
@class KernelUtxo;

@interface KernelAddress : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
- (NSData* _Nullable)publicSpendKey;
- (NSData* _Nullable)publicViewkey;
- (void)setPublicSpendKey:(NSData* _Nullable)k;
- (void)setPublicViewKey:(NSData* _Nullable)k;
- (NSString* _Nonnull)string;
@end

@interface KernelTx : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull hash;
@property (nonatomic) NSString* _Nonnull raw;
@property (nonatomic) KernelUtxo* _Nullable change;
@end

@interface KernelUtxo : NSObject <goSeqRefInterface> {
}
@property(strong, readonly) _Nonnull id _ref;

- (nonnull instancetype)initWithRef:(_Nonnull id)ref;
- (nonnull instancetype)init;
@property (nonatomic) NSString* _Nonnull hash;
@property (nonatomic) long index;
@property (nonatomic) NSString* _Nonnull amount;
@end

FOUNDATION_EXPORT NSString* _Nonnull KernelBuildTx(NSString* _Nullable asset, NSString* _Nullable amount, int32_t threshold, NSString* _Nullable receiverKeys, NSString* _Nullable receiverMask, NSData* _Nullable inputs, NSString* _Nullable changeKeys, NSString* _Nullable changeMask, NSString* _Nullable extra, NSString* _Nullable reference, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSString* _Nonnull KernelBuildTxToKernelAddress(NSString* _Nullable asset, NSString* _Nullable amount, NSString* _Nullable kenelAddress, NSData* _Nullable inputs, NSString* _Nullable changeKeys, NSString* _Nullable changeMask, NSString* _Nullable extra, NSString* _Nullable reference, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT KernelTx* _Nullable KernelBuildWithdrawalTx(NSString* _Nullable asset, NSString* _Nullable amount, NSString* _Nullable address, NSString* _Nullable tag, NSString* _Nullable feeAmount, NSString* _Nullable feeKeys, NSString* _Nullable feeMask, NSData* _Nullable inputs, NSString* _Nullable changeKeys, NSString* _Nullable changeMask, NSString* _Nullable extra, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT KernelAddress* _Nullable KernelNewMainAddressFromString(NSString* _Nullable s, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT KernelTx* _Nullable KernelSignTransaction(NSString* _Nullable raw, NSString* _Nullable viewKeys, NSString* _Nullable spendKey, long index, BOOL withoutFee, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT KernelTx* _Nullable KernelSignTx(NSString* _Nullable raw, NSString* _Nullable inputKeys, NSString* _Nullable viewKeys, NSString* _Nullable spendKey, BOOL withoutFee, NSError* _Nullable* _Nullable error);

#endif