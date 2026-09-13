#import <Foundation/Foundation.h>

@interface LTSettings : NSObject

+ (instancetype)sharedSettings;

- (BOOL)isEnabled;
- (BOOL)isFreezeEnabled;
- (BOOL)isScreenshotEnabled;
- (BOOL)isTranslateEnabled;
- (BOOL)isToolbarEnabled;

@end
