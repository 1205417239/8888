#import "LTSettings.h"

static NSString * const kLTDomain = @"com.lingua.tweak";

@implementation LTSettings

+ (instancetype)sharedSettings
{
    static LTSettings *settings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settings = [[self alloc] init];
    });
    return settings;
}

- (BOOL)boolForKey:(NSString *)key
{
    NSDictionary *domain =
        [[NSUserDefaults standardUserDefaults]
            persistentDomainForName:kLTDomain];

    if (!domain) {
        return YES;
    }

    NSNumber *value = domain[key];
    return value ? [value boolValue] : YES;
}

- (BOOL)isEnabled            { return [self boolForKey:@"LinguaTweakEnabled"]; }
- (BOOL)isFreezeEnabled      { return [self boolForKey:@"FreezeEnabled"]; }
- (BOOL)isScreenshotEnabled  { return [self boolForKey:@"ScreenshotEnabled"]; }
- (BOOL)isTranslateEnabled   { return [self boolForKey:@"TranslateEnabled"]; }
- (BOOL)isToolbarEnabled     { return [self boolForKey:@"ToolbarEnabled"]; }

@end
