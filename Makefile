ARCHS = arm64e
TARGET = iphone:clang:16.5:17.0

THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LinguaTweakPrefs

LinguaTweakPrefs_FILES = LTPrefsRootListController.m
LinguaTweakPrefs_INSTALL_PATH = /Library/PreferenceBundles

LinguaTweakPrefs_FRAMEWORKS = UIKit Foundation
LinguaTweakPrefs_PRIVATE_FRAMEWORKS = Preferences

LinguaTweakPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
