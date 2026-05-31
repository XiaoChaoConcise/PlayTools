//
//  NSObject+PrivateSwizzle.m
//  PlayTools
//
//  Created by siri on 06.10.2021.
//

#import "NSObject+Swizzle.h"
#import <objc/runtime.h>
#import "CoreGraphics/CoreGraphics.h"
#import "UIKit/UIKit.h"
#import <PlayTools/PlayTools-Swift.h>
#import "PTFakeMetaTouch.h"
#if !TARGET_OS_MACCATALYST
#import <VideoSubscriberAccount/VideoSubscriberAccount.h>
#endif
#import <AVFoundation/AVFoundation.h>
#import <CoreMotion/CoreMotion.h>
#import <GameController/GameController.h>

__attribute__((visibility("hidden")))
@interface PTSwizzleLoader : NSObject
@end

@implementation NSObject (Swizzle)

- (void) swizzleInstanceMethod:(SEL)origSelector withMethod:(SEL)newSelector
{
    Class cls = [self class];
    // If current class doesn't exist selector, then get super
    Method originalMethod = class_getInstanceMethod(cls, origSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, newSelector);
    
    // Add selector if it doesn't exist, implement append with method
    if (class_addMethod(cls,
                        origSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod)) ) {
        // Replace class instance method, added if selector not exist
        // For class cluster, it always adds new selector here
        class_replaceMethod(cls,
                            newSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
        
    } else {
        // SwizzleMethod maybe belongs to super
        class_replaceMethod(cls,
                            newSelector,
                            class_replaceMethod(cls,
                                                origSelector,
                                                method_getImplementation(swizzledMethod),
                                                method_getTypeEncoding(swizzledMethod)),
                            method_getTypeEncoding(originalMethod));
    }
}

- (void) swizzleExchangeMethod:(SEL)origSelector withMethod:(SEL)newSelector
{
    Class cls = [self class];
    // If current class doesn't exist selector, then get super
    Method originalMethod = class_getInstanceMethod(cls, origSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, newSelector);
    
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

+ (void) swizzleClassMethod:(SEL)origSelector withMethod:(SEL)newSelector {
    Class cls = object_getClass((id)self);
    Method originalMethod = class_getClassMethod(cls, origSelector);
    Method swizzledMethod = class_getClassMethod(cls, newSelector);

    if (class_addMethod(cls,
                        origSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(cls,
                            newSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        class_replaceMethod(cls,
                            newSelector,
                            class_replaceMethod(cls,
                                                origSelector,
                                                method_getImplementation(swizzledMethod),
                                                method_getTypeEncoding(swizzledMethod)),
                            method_getTypeEncoding(originalMethod));
    }
}

- (BOOL) hook_prefersPointerLocked {
    return false;
}

- (CGRect) hook_frameDefault {
    return [PlayScreen frameDefault:[self hook_frameDefault]];
}

- (CGRect) hook_boundsDefault {
    return [PlayScreen boundsDefault:[self hook_boundsDefault]];
}

- (CGRect) hook_nativeBoundsDefault {
    return [PlayScreen nativeBoundsDefault:[self hook_nativeBoundsDefault]];
}

- (CGSize) hook_sizeDelfault {
    return [PlayScreen sizeAspectRatioDefault:[self hook_sizeDelfault]];
}


- (CGRect) hook_frame {
    return [PlayScreen frame:[self hook_frame]];
}

- (CGRect) hook_bounds {
    return [PlayScreen bounds:[self hook_bounds]];
}

- (CGRect) hook_nativeBounds {
    return [PlayScreen nativeBounds:[self hook_nativeBounds]];
}

- (CGSize) hook_size {
    return [PlayScreen sizeAspectRatio:[self hook_size]];
}



- (long long) hook_orientation {
    return 0;
}

- (double) hook_nativeScale {
    return [[PlaySettings shared] customScaler];
}

- (double) hook_scale {
    return round([[PlaySettings shared] customScaler]);
}

- (double) get_default_height {
    return [[UIScreen mainScreen] bounds].size.height;
    
}
- (double) get_default_width {
    return [[UIScreen mainScreen] bounds].size.width;
    
}

- (CGRect) hook_boundsResizable {
    return [PlayScreen boundsResizable:[self hook_boundsResizable]];
}

- (BOOL) hook_requiresFullScreen {
    return NO;
}

#if !TARGET_OS_MACCATALYST
- (void) hook_setCurrentSubscription:(VSSubscription *)currentSubscription {
    // do nothing
}
#endif

- (NSString *)hook_stringByReplacingOccurrencesOfRegularExpressionPattern:(NSString *)pattern
                                                             withTemplate:(NSString *)template
                                                                  options:(NSRegularExpressionOptions)options
                                                                    range:(NSRange)range {
    if ([(NSString*)self isEqualToString:@""]) {
        return @"";
    }
    return [self hook_stringByReplacingOccurrencesOfRegularExpressionPattern:pattern
                                                                withTemplate:template
                                                                     options:options
                                                                       range:range];
}

- (void)hook_requestRecordPermission:(void (^)(BOOL))response {
    BOOL granted = [[AVAudioSession sharedInstance] recordPermission] == AVAudioSessionRecordPermissionGranted;
    if (granted) {
        response(granted);
    } else {
        [self hook_requestRecordPermission:response];
    }
}

- (instancetype)hook_CMMotionManager_init {
    CMMotionManager *motionManager = (CMMotionManager *)[self hook_CMMotionManager_init];
    motionManager.accelerometerUpdateInterval = 0.01;
    motionManager.deviceMotionUpdateInterval = 0.01;
    motionManager.gyroUpdateInterval = 0.01;
    return motionManager;
}

+ (GCMouse *)hook_GCMouse_current {
    return nil;
}

+ (NSArray *)hook_GCMouse_mice {
    return @[];
}

bool menuWasCreated = false;
- (id) initWithRootMenuHook:(id)rootMenu {
    self = [self initWithRootMenuHook:rootMenu];
    if (!menuWasCreated) {
        [PlayCover initMenuWithMenu: self];
        menuWasCreated = TRUE;
    }
    return self;
}

@end

@implementation PTSwizzleLoader
+ (void)load {
    if(@available(iOS 16.3, *)) {
        if ([[PlaySettings shared] resizableWindow]) {
            [objc_getClass("_UIApplicationInfoParser") swizzleInstanceMethod:NSSelectorFromString(@"requiresFullScreen") withMethod:@selector(hook_requiresFullScreen)];
            [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(bounds) withMethod:@selector(hook_boundsResizable)];
            [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeScale) withMethod:@selector(hook_nativeScale)];
            [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(scale) withMethod:@selector(hook_scale)];
        }
        else if ([[PlaySettings shared] adaptiveDisplay]) {
            if ([[PlaySettings shared] inverseScreenValues]) {
                if(@available(iOS 17.1, *))
                    [objc_getClass("FBSSceneSettingsCore") swizzleExchangeMethod:@selector(frame) withMethod:@selector(hook_frameDefault)];
                else
                    [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(frame) withMethod:@selector(hook_frameDefault)];
                [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(bounds) withMethod:@selector(hook_boundsDefault)];
                [objc_getClass("FBSDisplayMode") swizzleInstanceMethod:@selector(size) withMethod:@selector(hook_sizeDelfault)];
                
                [objc_getClass("UIDevice") swizzleInstanceMethod:@selector(orientation) withMethod:@selector(hook_orientation)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeBounds) withMethod:@selector(hook_nativeBoundsDefault)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeScale) withMethod:@selector(hook_nativeScale)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(scale) withMethod:@selector(hook_scale)];
            } else {
                if(@available(iOS 17.1, *))
                    [objc_getClass("FBSSceneSettingsCore") swizzleExchangeMethod:@selector(frame) withMethod:@selector(hook_frame)];
                else
                    [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(frame) withMethod:@selector(hook_frame)];
                [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(bounds) withMethod:@selector(hook_bounds)];
                [objc_getClass("FBSDisplayMode") swizzleInstanceMethod:@selector(size) withMethod:@selector(hook_size)];
                
                [objc_getClass("UIDevice") swizzleInstanceMethod:@selector(orientation) withMethod:@selector(hook_orientation)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeBounds) withMethod:@selector(hook_nativeBounds)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeScale) withMethod:@selector(hook_nativeScale)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(scale) withMethod:@selector(hook_scale)];   
            }
        }
        else {
            if ([[PlaySettings shared] windowFixMethod] == 1) {
            }
            else {
                CGFloat newValueW = (CGFloat) [self get_default_width];
                [[PlaySettings shared] setValue:@(newValueW) forKey:@"windowSizeWidth"];
                
                CGFloat newValueH = (CGFloat)[self get_default_height];
                [[PlaySettings shared] setValue:@(newValueH) forKey:@"windowSizeHeight"];
                if (![[PlaySettings shared] inverseScreenValues]) {
                    if(@available(iOS 17.1, *))
                        [objc_getClass("FBSSceneSettingsCore") swizzleExchangeMethod:@selector(frame) withMethod:@selector(hook_frameDefault)];
                    else
                        [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(frame) withMethod:@selector(hook_frameDefault)];
                    [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(bounds) withMethod:@selector(hook_boundsDefault)];
                    [objc_getClass("FBSDisplayMode") swizzleInstanceMethod:@selector(size) withMethod:@selector(hook_sizeDelfault)];
                }
                [objc_getClass("UIDevice") swizzleInstanceMethod:@selector(orientation) withMethod:@selector(hook_orientation)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeBounds) withMethod:@selector(hook_nativeBoundsDefault)];
                
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(nativeScale) withMethod:@selector(hook_nativeScale)];
                [objc_getClass("UIScreen") swizzleInstanceMethod:@selector(scale) withMethod:@selector(hook_scale)];
            }
        }
    } 
    else {
        if ([[PlaySettings shared] adaptiveDisplay]) {
                if(@available(iOS 17.1, *))
                    [objc_getClass("FBSSceneSettingsCore") swizzleExchangeMethod:@selector(frame) withMethod:@selector(hook_frame)];
                else
                    [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(frame) withMethod:@selector(hook_frame)];
                [objc_getClass("FBSSceneSettings") swizzleInstanceMethod:@selector(bounds) withMethod:@selector(hook_bounds)];
                [objc_getClass("FBSDisplayMode") swizzleInstanceMethod:@selector(size) withMethod:@selector(hook_size)];
            }
    }
    
    [objc_getClass("_UIMenuBuilder") swizzleInstanceMethod:sel_getUid("initWithRootMenu:") withMethod:@selector(initWithRootMenuHook:)];
    [objc_getClass("IOSViewController") swizzleInstanceMethod:@selector(prefersPointerLocked) withMethod:@selector(hook_prefersPointerLocked)];

#if !TARGET_OS_MACCATALYST
    [objc_getClass("VSSubscriptionRegistrationCenter") swizzleInstanceMethod:@selector(setCurrentSubscription:) withMethod:@selector(hook_setCurrentSubscription:)];
#endif

    if (PlayInfo.isUnrealEngine) {
        CFStringEncoding encoding = CFStringGetSystemEncoding();
        if (encoding == kCFStringEncodingMacChineseSimp || encoding == kCFStringEncodingMacChineseTrad) {
            SEL origSelector = NSSelectorFromString(@"_stringByReplacingOccurrencesOfRegularExpressionPattern:withTemplate:options:range:");
            SEL newSelector = @selector(hook_stringByReplacingOccurrencesOfRegularExpressionPattern:withTemplate:options:range:);
            [objc_getClass("NSString") swizzleInstanceMethod:origSelector withMethod:newSelector];
        }
    }

    if ([[PlaySettings shared] checkMicPermissionSync]) {
        [objc_getClass("AVAudioSession") swizzleInstanceMethod:@selector(requestRecordPermission:) withMethod:@selector(hook_requestRecordPermission:)];
    }

    if ([[PlaySettings shared] limitMotionUpdateFrequency]) {
        [objc_getClass("CMMotionManager") swizzleInstanceMethod:@selector(init) withMethod:@selector(hook_CMMotionManager_init)];
    }

    if (([[PlaySettings shared] disableBuiltinMouse])) {
        [objc_getClass("GCMouse") swizzleClassMethod:@selector(current) withMethod:@selector(hook_GCMouse_current)];
        [objc_getClass("GCMouse") swizzleClassMethod:@selector(mice) withMethod:@selector(hook_GCMouse_mice)];
    }
}

@end
