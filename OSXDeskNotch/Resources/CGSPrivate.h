//
//  CGSPrivate.h
//
//  Declarations for private CoreGraphics SPI used to enumerate and switch
//  macOS Spaces. These symbols live inside CoreGraphics.framework but are
//  not exposed via any public header. Linking is satisfied automatically
//  because CoreGraphics is already linked by AppKit.
//
//  IMPORTANT: Use of these symbols disqualifies the app from the Mac App
//  Store. The app must be distributed via Developer ID + notarization.
//

#ifndef CGSPrivate_h
#define CGSPrivate_h

#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

CF_ASSUME_NONNULL_BEGIN

typedef int CGSConnectionID;
typedef uint64_t CGSSpaceID;

/// Returns the calling process's connection to the WindowServer.
extern CGSConnectionID CGSMainConnectionID(void);

/// Returns an array of display dictionaries. Each dictionary contains:
///   - "Display Identifier": CFStringRef display UUID
///   - "Spaces":             CFArrayRef of space dictionaries
///   - "Current Space":      space dictionary
///
/// Each space dictionary contains:
///   - "ManagedSpaceID": CFNumberRef (the CGSSpaceID we operate on)
///   - "type":           CFNumberRef (0 = user space, 4 = full-screen app space)
///   - "uuid":           CFStringRef (per-space UUID)
///
/// Caller owns the returned CFArrayRef (Create Rule). May be NULL on error.
extern CFArrayRef _Nullable CGSCopyManagedDisplaySpaces(CGSConnectionID cid)
    CF_RETURNS_RETAINED;

/// Returns the currently visible space on the given display.
extern CGSSpaceID CGSManagedDisplayGetCurrentSpace(CGSConnectionID cid,
                                                  CFStringRef displayUUID);

/// Switches the given display to the supplied space. WindowServer animates
/// the transition the same way Mission Control would.
extern void CGSManagedDisplaySetCurrentSpace(CGSConnectionID cid,
                                             CFStringRef displayUUID,
                                             CGSSpaceID spaceID);

CF_ASSUME_NONNULL_END

#endif /* CGSPrivate_h */
