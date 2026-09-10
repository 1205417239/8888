#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface LTPrefsRootListController : PSListController
@end

@implementation LTPrefsRootListController

- (NSArray *)specifiers
{
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root"
                                                  target:self];
    }

    return _specifiers;
}

@end
