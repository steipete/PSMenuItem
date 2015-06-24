// PSMenuItem.m
//
// Copyright (c) 2012 Peter Steinberger (http://petersteinberger.com)
// This code is a part of http://pspdfkit.com and has been put under MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "PSMenuItem.h"
#import <objc/runtime.h>
#import <objc/message.h>

// imp_implementationWithBlock changed it's type in iOS6 (XCode 4.5)
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
#define PSPDFBlockImplCast (__bridge void *)
#else
#define PSPDFBlockImplCast
#endif

NSString *kMenuItemTrailer = @"ps_performMenuItem";

// Add method + swizzle.
void PSPDFReplaceMethod(Class c, SEL origSEL, SEL newSEL, IMP impl);
void PSPDFReplaceMethod(Class c, SEL origSEL, SEL newSEL, IMP impl) {
    Method origMethod = class_getInstanceMethod(c, origSEL);
    class_addMethod(c, newSEL, impl, method_getTypeEncoding(origMethod));
    Method newMethod = class_getInstanceMethod(c, newSEL);
    if(class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

// Checks for our custom selector.
BOOL PSPDFIsMenuItemSelector(SEL selector);
BOOL PSPDFPIsMenuItemSelector(SEL selector) {
    return [NSStringFromSelector(selector) hasPrefix:kMenuItemTrailer];
}

@interface PSMenuItem()
@property(nonatomic, assign) SEL customSelector;
@end

@implementation PSMenuItem

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Static

/*
 This might look scary, but it's actually not that bad.
 We hook into the three methods of UIResponder and NSObject to capture calls to our custom created selector.
 Then we find the UIMenuController and search for the corresponding PSMenuItem.
 If the kMenuItemTrailer is not detected, we call the original implementation.

 This all wouldn't be necessary if UIMenuController would call our selectors with the UIMenuItem as sender.
 */
+ (void)installMenuHandlerForObject:(id)object {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    @autoreleasepool {
        @synchronized(self) {
            // object can be both a class or an instance of a class.
            Class objectClass = class_isMetaClass(object_getClass(object)) ? object : [object class];

            // check if menu handler has been already installed.
            SEL canPerformActionSEL = @selector(pspdf_canPerformAction:withSender:);
            if (!class_getInstanceMethod(objectClass, canPerformActionSEL)) {

                // add canBecomeFirstResponder if it is not returning YES. (or if we don't know)
                if (object == objectClass || ![object canBecomeFirstResponder]) {
                    SEL canBecomeFRSEL = @selector(pspdf_canBecomeFirstResponder);
                    IMP canBecomeFRIMP = imp_implementationWithBlock(PSPDFBlockImplCast(^(id _self) {
                        return YES;
                    }));
                    PSPDFReplaceMethod(objectClass, @selector(canBecomeFirstResponder), canBecomeFRSEL, canBecomeFRIMP);
                }

                // swizzle canPerformAction:withSender: for our custom selectors.
                // Queried before the UIMenuController is shown.
                IMP canPerformActionIMP = imp_implementationWithBlock(PSPDFBlockImplCast(^(id _self, SEL action, id sender) {
                    return PSPDFPIsMenuItemSelector(action) ? YES : ((BOOL (*)(id, SEL, SEL, id))objc_msgSend)(_self, canPerformActionSEL, action, sender);
                }));
                PSPDFReplaceMethod(objectClass, @selector(canPerformAction:withSender:), canPerformActionSEL, canPerformActionIMP);

                // swizzle methodSignatureForSelector:.
                SEL methodSignatureSEL = @selector(pspdf_methodSignatureForSelector:);
                IMP methodSignatureIMP = imp_implementationWithBlock(PSPDFBlockImplCast(^(id _self, SEL selector) {
                    if (PSPDFPIsMenuItemSelector(selector)) {
                        return [NSMethodSignature signatureWithObjCTypes:"v@:@"]; // fake it.
                    }else {
                        return ((NSMethodSignature * (*)(id, SEL, SEL))objc_msgSend)(_self, methodSignatureSEL, selector);
                    }
                }));
                PSPDFReplaceMethod(objectClass, @selector(methodSignatureForSelector:), methodSignatureSEL, methodSignatureIMP);

                // swizzle forwardInvocation:
                SEL forwardInvocationSEL = @selector(pspdf_forwardInvocation:);
                IMP forwardInvocationIMP = imp_implementationWithBlock(PSPDFBlockImplCast(^(id _self, NSInvocation *invocation) {
                    if (PSPDFPIsMenuItemSelector([invocation selector])) {
                        for (PSMenuItem *menuItem in [UIMenuController sharedMenuController].menuItems) {
                            if ([menuItem isKindOfClass:[PSMenuItem class]] && sel_isEqual([invocation selector], menuItem.customSelector)) {
                                [menuItem performBlock]; break; // find corresponding MenuItem and forward
                            }
                        }
                    }else {
                        ((void (*)(id, SEL, NSInvocation *))objc_msgSend)(_self, forwardInvocationSEL, invocation);
                    }
                }));
                PSPDFReplaceMethod(objectClass, @selector(forwardInvocation:), forwardInvocationSEL, forwardInvocationIMP);
            }
        }
    }
#pragma clang diagnostic pop
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)initWithTitle:(NSString *)title block:(void(^)())block {
    // Create a unique, still debuggable selector unique per PSMenuItem.
    NSString *strippedTitle = [[[title componentsSeparatedByCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] componentsJoinedByString:@""] lowercaseString];
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
    CFRelease(uuid);
    SEL customSelector = NSSelectorFromString([NSString stringWithFormat:@"%@_%@_%@:", kMenuItemTrailer, strippedTitle, uuidString]);

    if((self = [super initWithTitle:title action:customSelector])) {
        self.customSelector = customSelector;
        _enabled = YES;
        _block = [block copy];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

// Nils out action selector if we get disabled; auto-hides it from the UIMenuController.
- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    self.action = enabled ? self.customSelector : NULL;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private

// Trampuline executor.
- (void)performBlock {
    if (_block) _block();
}

@end
