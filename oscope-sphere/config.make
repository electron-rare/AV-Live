################################################################################
# CONFIGURE PROJECT MAKEFILE  (optional)
# This file is where we make project specific configurations.
################################################################################

################################################################################
# OF ROOT
################################################################################
OF_ROOT = ../../..

################################################################################
# PROJECT EXCLUSIONS
################################################################################
# PROJECT_EXCLUSIONS =

################################################################################
# LIBUSB AUTO-DETECT
#   Préfère pkg-config (Apple Silicon + Intel + Linux), fallback à
#   `brew --prefix libusb` si pkg-config n'est pas installé.
################################################################################
HAS_PKGCONFIG := $(shell command -v pkg-config 2>/dev/null)
ifneq ($(HAS_PKGCONFIG),)
    LIBUSB_CFLAGS := $(shell pkg-config --cflags libusb-1.0)
    LIBUSB_LDFLAGS := $(shell pkg-config --libs libusb-1.0)
else
    HAS_BREW := $(shell command -v brew 2>/dev/null)
    ifneq ($(HAS_BREW),)
        LIBUSB_PREFIX := $(shell brew --prefix libusb)
        LIBUSB_CFLAGS := -I$(LIBUSB_PREFIX)/include/libusb-1.0
        LIBUSB_LDFLAGS := -L$(LIBUSB_PREFIX)/lib -lusb-1.0
    else
        # Fallback générique
        LIBUSB_CFLAGS := -I/usr/local/include/libusb-1.0 -I/opt/homebrew/include/libusb-1.0
        LIBUSB_LDFLAGS := -L/usr/local/lib -L/opt/homebrew/lib -lusb-1.0
    endif
endif

PROJECT_CFLAGS  = $(LIBUSB_CFLAGS)
PROJECT_LDFLAGS = $(LIBUSB_LDFLAGS)

################################################################################
# PROJECT CPPFLAGS
################################################################################
PROJECT_CPPFLAGS = -std=c++17

################################################################################
# PROJECT OPTIMIZATION CFLAGS
################################################################################
# PROJECT_OPTIMIZATION_CFLAGS_RELEASE =
# PROJECT_OPTIMIZATION_CFLAGS_DEBUG =
