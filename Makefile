DEBUG = 0
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:13.0

INSTALL_TARGET_PROCESSES = Zebra

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StripeCount

StripeCount_FILES = Tweak.mm
StripeCount_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
