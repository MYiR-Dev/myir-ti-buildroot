################################################################################
#
# xlib_libXfixes -- X.Org Xfixes library
#
################################################################################

XLIB_LIBXFIXES_VERSION = 4.0.4
XLIB_LIBXFIXES_SOURCE = libXfixes-$(XLIB_LIBXFIXES_VERSION).tar.bz2
XLIB_LIBXFIXES_SITE = http://xorg.freedesktop.org/releases/individual/lib
XLIB_LIBXFIXES_INSTALL_STAGING = YES
XLIB_LIBXFIXES_DEPENDENCIES = xproto_fixesproto xlib_libX11 xproto_xextproto xproto_xproto

$(eval $(call AUTOTARGETS))
$(eval $(call AUTOTARGETS,host))
