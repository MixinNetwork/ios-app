// Objective-C API for talking to mixin/ed25519 Go package.
//   gobind -lang=objc mixin/ed25519
//
// File is generated by gobind. Do not edit.

#ifndef __Ed25519_H__
#define __Ed25519_H__

@import Foundation;
#include "ref.h"
#include "Universe.objc.h"


FOUNDATION_EXPORT NSData* _Nullable Ed25519GenerateKey(void);

FOUNDATION_EXPORT NSData* _Nullable Ed25519NewKeyFromSeed(NSData* _Nullable seed);

FOUNDATION_EXPORT NSData* _Nullable Ed25519PublicKeyToCurve25519(NSData* _Nullable pub, NSError* _Nullable* _Nullable error);

FOUNDATION_EXPORT NSData* _Nullable Ed25519Sign(NSData* _Nullable message, NSData* _Nullable seed);

FOUNDATION_EXPORT BOOL Ed25519Verify(NSData* _Nullable message, NSData* _Nullable sig, NSData* _Nullable pub);

#endif