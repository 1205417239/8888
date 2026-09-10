#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface LTPrefsRootListController : PSListController
@end

@implementation LTPrefsRootListController

- (NSArray *)specifiers
{
    if (!_specifiers) {

        NSMutableArray *specifiers = [NSMutableArray array];

        PSSpecifier *group =
        [PSSpecifier preferenceSpecifierNamed:@"灵语助手"
                                        target:self
                                           set:nil
                                           get:nil
                                        detail:nil
                                          cell:PSGroupCell
                                          edit:nil];

        [specifiers addObject:group];

        NSArray *items = @[
            @[@"冻结", @"FreezeEnabled"],
            @[@"截图", @"ScreenshotEnabled"],
            @[@"翻译", @"TranslateEnabled"],
            @[@"AI助手", @"AIEnabled"],
            @[@"编辑器", @"EditorEnabled"],
            @[@"长截图", @"LongShotEnabled"],
            @[@"Sileo翻译", @"SileoTranslateEnabled"]
        ];

        for (NSArray *item in items) {

            PSSpecifier *specifier =
            [PSSpecifier preferenceSpecifierNamed:item[0]
                                            target:self
                                               set:@selector(setPreferenceValue:specifier:)
                                               get:@selector(readPreferenceValue:)
                                            detail:nil
                                              cell:PSSwitchCell
                                              edit:nil];

            [specifier setProperty:item[1] forKey:@"key"];
            [specifier setProperty:@"com.lingua.tweak" forKey:@"defaults"];
            [specifier setProperty:@YES forKey:@"default"];

            [specifiers addObject:specifier];
        }

        _specifiers = [specifiers copy];
    }

    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
    NSString *key = [specifier propertyForKey:@"key"];
    NSString *defaults = [specifier propertyForKey:@"defaults"];

    if (key && defaults) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key = [specifier propertyForKey:@"key"];

    if (!key) {
        return @YES;
    }

    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];

    if (value == nil) {
        return @YES;
    }

    return value;
}

@end
