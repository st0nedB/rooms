#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Moscapsule.h"
#import "MosquittoCallbackBridge.h"
#import "mosquitto.h"

FOUNDATION_EXPORT double MoscapsuleVersionNumber;
FOUNDATION_EXPORT const unsigned char MoscapsuleVersionString[];

