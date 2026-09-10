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
        [PSSpecifier preferenceSpecifierNamed:@"LinguaTweak"
                                        target:self
                                           set:nil
                                           get:nil
                                        detail:nil
                                          cell:PSGroupCell
                                          edit:nil];

        [specifiers addObject:group];

        NSArray *items = @[
            @[@"Freeze", @"FreezeEnabled"],
            @[@"Screenshot", @"ScreenshotEnabled"],
            @[@"Translate", @"TranslateEnabled"],
            @[@"AI Assistant", @"AIEnabled"],
            @[@"Editor", @"EditorEnabled"],
            @[@"LongShot", @"LongShotEnabled"],
            @[@"Sileo Translate", @"SileoTranslateEnabled"]
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
