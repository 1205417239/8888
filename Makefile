ARCHS = arm64e
TARGET = iphone:clang:16.5:17.0
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LinguaTweak

LinguaTweak_FILES = Tweak.x \
                    Sources/Freeze/LTFreezeManager.m

LinguaTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
LinguaTweak_FRAMEWORKS = UIKit Foundation

BUNDLE_NAME = LinguaTweakPrefs

LinguaTweakPrefs_FILES = LinguaTweakPrefs/LTPrefsRootListController.m
LinguaTweakPrefs_INSTALL_PATH = /Library/PreferenceBundles
LinguaTweakPrefs_FRAMEWORKS = UIKit Foundation
LinguaTweakPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
