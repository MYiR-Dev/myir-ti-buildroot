# Makefile for to build a gcc/uClibc toolchain
#
# Copyright (C) 2002-2003 Erik Andersen <andersen@uclibc.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

ifneq ($(GCC_2_95_TOOLCHAIN),true)

# Older stuff...
#GCC_SITE:=ftp://ftp.gnu.org/gnu/gcc/
#GCC_SOURCE:=gcc-3.3.tar.gz
#GCC_DIR:=$(TOOL_BUILD_DIR)/gcc-3.3
#GCC_CAT:=zcat

# Shiney new stuff...
GCC_VERSION:=3.3.1
GCC_SITE:=http://gcc.get-software.com/releases/gcc-$(GCC_VERSION)
GCC_SOURCE:=gcc-$(GCC_VERSION).tar.bz2
GCC_DIR:=$(TOOL_BUILD_DIR)/gcc-$(GCC_VERSION)
GCC_CAT:=bzcat

#############################################################
#
# Setup some initial stuff
#
#############################################################
ifeq ($(INSTALL_LIBSTDCPP),true)
TARGET_LANGUAGES:=c,c++
else
TARGET_LANGUAGES:=c
endif

#############################################################
#
# build the first pass gcc compiler
#
#############################################################
GCC_BUILD_DIR1:=$(TOOL_BUILD_DIR)/gcc-3.3-initial
$(DL_DIR)/$(GCC_SOURCE):
	$(WGET) -P $(DL_DIR) $(GCC_SITE)/$(GCC_SOURCE)

$(GCC_DIR)/.unpacked: $(DL_DIR)/$(GCC_SOURCE)
	$(GCC_CAT) $(DL_DIR)/$(GCC_SOURCE) | tar -C $(TOOL_BUILD_DIR) -xvf -
	touch $(GCC_DIR)/.unpacked

$(GCC_DIR)/.patched: $(GCC_DIR)/.unpacked
	# Apply any files named gcc-*.patch from the source directory to gcc
	$(SOURCE_DIR)/patch-kernel.sh $(GCC_DIR) $(SOURCE_DIR) gcc-*.patch
	touch $(GCC_DIR)/.patched

$(GCC_DIR)/.gcc3_3_build_hacks: $(GCC_DIR)/.patched
	#
	# Hack things to use the correct shared lib loader
	#
	(cd $(GCC_DIR); set -e; export LIST=`grep -lr -- "-dynamic-linker.*\.so[\.0-9]*" *`;\
		if [ -n "$$LIST" ] ; then \
		perl -i -p -e "s,-dynamic-linker.*\.so[\.0-9]*},\
		    -dynamic-linker /lib/ld-uClibc.so.0},;" $$LIST; fi);
	#
	# Prevent system glibc start files from leaking in uninvited...
	#
	perl -i -p -e "s,standard_startfile_prefix_1 = \".*,standard_startfile_prefix_1 =\
		\"$(STAGING_DIR)/lib/\";,;" $(GCC_DIR)/gcc/gcc.c;
	perl -i -p -e "s,standard_startfile_prefix_2 = \".*,standard_startfile_prefix_2 =\
		\"$(STAGING_DIR)/usr/lib/\";,;" $(GCC_DIR)/gcc/gcc.c;
	#
	# Prevent system glibc include files from leaking in uninvited...
	#
	perl -i -p -e "s,^NATIVE_SYSTEM_HEADER_DIR.*,NATIVE_SYSTEM_HEADER_DIR=\
		$(STAGING_DIR)/include,;" $(GCC_DIR)/gcc/Makefile.in;
	perl -i -p -e "s,^CROSS_SYSTEM_HEADER_DIR.*,CROSS_SYSTEM_HEADER_DIR=\
		$(STAGING_DIR)/include,;" $(GCC_DIR)/gcc/Makefile.in;
	perl -i -p -e "s,^#define.*STANDARD_INCLUDE_DIR.*,#define STANDARD_INCLUDE_DIR \
		\"$(STAGING_DIR)/include\",;" $(GCC_DIR)/gcc/cppdefault.h;
	#
	# Prevent system glibc libraries from being found by collect2 
	# when it calls locatelib() and rummages about the system looking 
	# for libraries with the correct name...
	#
	perl -i -p -e "s,\"/lib,\"$(STAGING_DIR)/lib,g;" $(GCC_DIR)/gcc/collect2.c
	perl -i -p -e "s,\"/usr/,\"$(STAGING_DIR)/usr/,g;" $(GCC_DIR)/gcc/collect2.c
	#
	# Prevent gcc from using the unwind-dw2-fde-glibc code
	#
	perl -i -p -e "s,^#ifndef inhibit_libc,#define inhibit_libc\n\
		#ifndef inhibit_libc,g;" $(GCC_DIR)/gcc/unwind-dw2-fde-glibc.c;
	touch $(GCC_DIR)/.gcc3_3_build_hacks

# The --without-headers option stopped working with gcc 3.0 and has never been
# # fixed, so we need to actually have working C library header files prior to
# # the step or libgcc will not build...
$(GCC_BUILD_DIR1)/.configured: $(GCC_DIR)/.gcc3_3_build_hacks
	mkdir -p $(GCC_BUILD_DIR1)
	(cd $(GCC_BUILD_DIR1); PATH=$(TARGET_PATH) AR=$(TARGET_CROSS)ar \
		RANLIB=$(TARGET_CROSS)ranlib CC=$(HOSTCC) \
		$(GCC_DIR)/configure \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_HOST_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=$(STAGING_DIR) \
		--exec-prefix=$(STAGING_DIR) \
		--bindir=$(STAGING_DIR)/bin \
		--sbindir=$(STAGING_DIR)/sbin \
		--sysconfdir=$(STAGING_DIR)/etc \
		--datadir=$(STAGING_DIR)/share \
		--includedir=$(STAGING_DIR)/include \
		--libdir=$(STAGING_DIR)/lib \
		--localstatedir=$(STAGING_DIR)/var \
		--mandir=$(STAGING_DIR)/man \
		--infodir=$(STAGING_DIR)/info \
		--with-local-prefix=$(STAGING_DIR)/usr/local \
		--oldincludedir=$(STAGING_DIR)/include $(MULTILIB) \
		--enable-target-optspace $(DISABLE_NLS) --with-gnu-ld \
		--disable-shared --enable-languages=c --disable-__cxa_atexit \
		$(EXTRA_GCC_CONFIG_OPTIONS) --program-prefix=$(ARCH)-uclibc-);
	touch $(GCC_BUILD_DIR1)/.configured

$(GCC_BUILD_DIR1)/.compiled: $(GCC_BUILD_DIR1)/.configured
	PATH=$(TARGET_PATH) $(MAKE) -C $(GCC_BUILD_DIR1) \
	    AR_FOR_TARGET=$(STAGING_DIR)/bin/$(ARCH)-uclibc-ar \
	    RANLIB_FOR_TARGET=$(STAGING_DIR)/bin/$(ARCH)-uclibc-ranlib
	touch $(GCC_BUILD_DIR1)/.compiled

$(STAGING_DIR)/bin/$(ARCH)-uclibc-gcc: $(GCC_BUILD_DIR1)/.compiled
	PATH=$(TARGET_PATH) $(MAKE) -C $(GCC_BUILD_DIR1) install;
	#Cleanup then mess when --program-prefix mysteriously fails 
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-cpp $(STAGING_DIR)/bin/$(ARCH)-uclibc-cpp
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-gcc $(STAGING_DIR)/bin/$(ARCH)-uclibc-gcc
	rm -f $(STAGING_DIR)/bin/gccbug $(STAGING_DIR)/bin/gcov
	rm -rf $(STAGING_DIR)/info $(STAGING_DIR)/man $(STAGING_DIR)/share/doc \
		$(STAGING_DIR)/share/locale

gcc3_3_initial: binutils uclibc-configured $(STAGING_DIR)/bin/$(ARCH)-uclibc-gcc

gcc3_3_initial-clean:
	rm -rf $(GCC_BUILD_DIR1)
	rm -f $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)*

gcc3_3_initial-dirclean:
	rm -rf $(GCC_BUILD_DIR1)



#############################################################
#
# second pass compiler build.  Build the compiler targeting 
# the newly built shared uClibc library.
#
#############################################################
GCC_BUILD_DIR2:=$(TOOL_BUILD_DIR)/gcc-3.3-final
$(GCC_DIR)/.g++_build_hacks: $(GCC_DIR)/.patched
	#
	# Hack up the soname for libstdc++
	# 
	perl -i -p -e "s,\.so\.1,.so.0.9.9,g;" $(GCC_DIR)/gcc/config/t-slibgcc-elf-ver;
	perl -i -p -e "s,-version-info.*[0-9]:[0-9]:[0-9],-version-info 9:9:0,g;" \
		$(GCC_DIR)/libstdc++-v3/src/Makefile.am $(GCC_DIR)/libstdc++-v3/src/Makefile.in;
	perl -i -p -e "s,3\.0\.0,9.9.0,g;" $(GCC_DIR)/libstdc++-v3/acinclude.m4 \
		$(GCC_DIR)/libstdc++-v3/aclocal.m4 $(GCC_DIR)/libstdc++-v3/configure;
	touch $(GCC_DIR)/.g++_build_hacks

$(GCC_BUILD_DIR2)/.configured: $(GCC_DIR)/.g++_build_hacks
	mkdir -p $(GCC_BUILD_DIR2)
	(cd $(GCC_BUILD_DIR2); PATH=$(TARGET_PATH) AR=$(TARGET_CROSS)ar \
		RANLIB=$(TARGET_CROSS)ranlib LD=$(TARGET_CROSS)ld \
		NM=$(TARGET_CROSS)nm CC=$(HOSTCC) \
		$(GCC_DIR)/configure \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_HOST_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=$(STAGING_DIR) \
		--exec-prefix=$(STAGING_DIR) \
		--bindir=$(STAGING_DIR)/bin \
		--sbindir=$(STAGING_DIR)/sbin \
		--sysconfdir=$(STAGING_DIR)/etc \
		--datadir=$(STAGING_DIR)/share \
		--localstatedir=$(STAGING_DIR)/var \
		--mandir=$(STAGING_DIR)/man \
		--infodir=$(STAGING_DIR)/info \
		--with-local-prefix=$(STAGING_DIR)/usr/local \
		--libdir=$(STAGING_DIR)/lib \
		--includedir=$(STAGING_DIR)/include \
		--with-gxx-include-dir=$(STAGING_DIR)/include/c++ \
		--oldincludedir=$(STAGING_DIR)/include \
		--enable-shared $(MULTILIB) \
		--enable-target-optspace $(DISABLE_NLS) \
		--with-gnu-ld --disable-__cxa_atexit \
		--enable-languages=$(TARGET_LANGUAGES) \
		$(EXTRA_GCC_CONFIG_OPTIONS) \
		--program-prefix=$(ARCH)-uclibc- \
	);
	touch $(GCC_BUILD_DIR2)/.configured

$(GCC_BUILD_DIR2)/.compiled: $(GCC_BUILD_DIR2)/.configured
	PATH=$(TARGET_PATH) CC=$(HOSTCC) \
	    AR_FOR_TARGET=$(TARGET_CROSS)ar RANLIB_FOR_TARGET=$(TARGET_CROSS)ranlib \
	    LD_FOR_TARGET=$(TARGET_CROSS)ld NM_FOR_TARGET=$(TARGET_CROSS)nm \
	    CC_FOR_TARGET=$(TARGET_CROSS)gcc $(MAKE) -C $(GCC_BUILD_DIR2)
	touch $(GCC_BUILD_DIR2)/.compiled

$(GCC_BUILD_DIR2)/.installed: $(GCC_BUILD_DIR2)/.compiled
	touch $(GCC_BUILD_DIR2)/.installed

$(STAGING_DIR)/bin/$(ARCH)-uclibc-g++: $(GCC_BUILD_DIR2)/.compiled
	PATH=$(TARGET_PATH) $(MAKE) -C $(GCC_BUILD_DIR2) install;
	-mv $(STAGING_DIR)/bin/gcc $(STAGING_DIR)/usr/bin;
	-mv $(STAGING_DIR)/bin/protoize $(STAGING_DIR)/usr/bin;
	-mv $(STAGING_DIR)/bin/unprotoize $(STAGING_DIR)/usr/bin;
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-cpp $(STAGING_DIR)/bin/$(ARCH)-uclibc-cpp
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-gcc $(STAGING_DIR)/bin/$(ARCH)-uclibc-gcc
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-c++ $(STAGING_DIR)/bin/$(ARCH)-uclibc-c++
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-g++ $(STAGING_DIR)/bin/$(ARCH)-uclibc-g++
	-mv $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-c++filt $(STAGING_DIR)/bin/$(ARCH)-uclibc-c++filt
	rm -f $(STAGING_DIR)/bin/cpp $(STAGING_DIR)/bin/gcov $(STAGING_DIR)/bin/*gccbug
	rm -f $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)-$(ARCH)-uclibc-*
	rm -rf $(STAGING_DIR)/info $(STAGING_DIR)/man $(STAGING_DIR)/share/doc \
		$(STAGING_DIR)/share/locale
	# Strip the host binaries
	-strip --strip-all -R .note -R .comment $(STAGING_DIR)/bin/*
	set -e; \
	for app in cc gcc c89 cpp c++ g++ ; do \
		if [ -x $(STAGING_DIR)/bin/$(ARCH)-uclibc-$${app} ] ; then \
		    (cd $(STAGING_DIR)/usr/bin; \
			ln -fs ../../bin/$(ARCH)-uclibc-$${app} $${app}; \
		    ); \
		fi; \
	done;

ifneq ($(TARGET_DIR),)
$(TARGET_DIR)/lib/libstdc++.so.5.0.5: $(STAGING_DIR)/lib/libstdc++.so.5.0.5
	cp -a $(STAGING_DIR)/lib/libstdc++.so* $(TARGET_DIR)/lib/

$(TARGET_DIR)/lib/libgcc_s.so.0.9.9: $(STAGING_DIR)/lib/libgcc_s.so.0.9.9
	cp -a $(STAGING_DIR)/lib/libgcc_s.so* $(TARGET_DIR)/lib/

ifeq ($(INSTALL_LIBSTDCPP),true)
GCC_TARGETS= $(TARGET_DIR)/lib/libgcc_s.so.0.9.9 $(TARGET_DIR)/lib/libstdc++.so.5.0.5 
else
GCC_TARGETS= $(TARGET_DIR)/lib/libgcc_s.so.0.9.9
endif
endif


gcc3_3: binutils uclibc-configured gcc3_3_initial uclibc \
	$(STAGING_DIR)/bin/$(ARCH)-uclibc-g++ $(GCC_TARGETS)

gcc3_3-clean:
	rm -rf $(GCC_BUILD_DIR2)
	rm -f $(STAGING_DIR)/bin/$(GNU_TARGET_NAME)*

gcc3_3-dirclean:
	rm -rf $(GCC_BUILD_DIR2)






#############################################################
#
# Next build target gcc compiler
#
#############################################################
GCC_BUILD_DIR3:=$(BUILD_DIR)/gcc-3.3-target

ifeq ($(HOST_ARCH),$(ARCH))
TARGET_GCC_ARGS=$(TARGET_CONFIGURE_OPTS)
endif

# We need to unpack a pristine source tree to avoid some of
# the previously applied hacks, which do not apply here...
$(GCC_BUILD_DIR3)/.unpacked: $(DL_DIR)/$(GCC_SOURCE)
	$(GCC_CAT) $(DL_DIR)/$(GCC_SOURCE) | tar -C $(BUILD_DIR) -xvf -
	mv $(BUILD_DIR)/gcc-$(GCC_VERSION) $(GCC_BUILD_DIR3)
	touch $(GCC_BUILD_DIR3)/.unpacked

$(GCC_BUILD_DIR3)/.patched: $(GCC_BUILD_DIR3)/.unpacked
	# Apply any files named gcc-*.patch from the source directory to gcc
	$(SOURCE_DIR)/patch-kernel.sh $(GCC_BUILD_DIR3) $(SOURCE_DIR) gcc-*.patch
	touch $(GCC_BUILD_DIR3)/.patched

$(GCC_BUILD_DIR3)/.gcc3_3_build_hacks: $(GCC_BUILD_DIR3)/.patched
	#
	# Hack things to use the correct shared lib loader
	#
	(cd $(GCC_BUILD_DIR3); set -e; export LIST=`grep -lr -- "-dynamic-linker.*\.so[\.0-9]*" *`;\
		if [ -n "$$LIST" ] ; then \
		perl -i -p -e "s,-dynamic-linker.*\.so[\.0-9]*},\
		    -dynamic-linker /lib/ld-uClibc.so.0},;" $$LIST; fi);
	#
	# Prevent gcc from using the unwind-dw2-fde-glibc code
	#
	perl -i -p -e "s,^#ifndef inhibit_libc,#define inhibit_libc\n\
		#ifndef inhibit_libc,g;" $(GCC_BUILD_DIR3)/gcc/unwind-dw2-fde-glibc.c;
	#
	# Hack up the soname for libstdc++
	# 
	perl -i -p -e "s,\.so\.1,.so.0.9.9,g;" $(GCC_BUILD_DIR3)/gcc/config/t-slibgcc-elf-ver;
	perl -i -p -e "s,-version-info.*[0-9]:[0-9]:[0-9],-version-info 9:9:0,g;" \
		$(GCC_BUILD_DIR3)/libstdc++-v3/src/Makefile.am \
		$(GCC_BUILD_DIR3)/libstdc++-v3/src/Makefile.in;
	perl -i -p -e "s,3\.0\.0,9.9.0,g;" $(GCC_BUILD_DIR3)/libstdc++-v3/acinclude.m4 \
		$(GCC_BUILD_DIR3)/libstdc++-v3/aclocal.m4 \
		$(GCC_BUILD_DIR3)/libstdc++-v3/configure;
	touch $(GCC_BUILD_DIR3)/.gcc3_3_build_hacks

$(GCC_BUILD_DIR3)/.configured: $(GCC_BUILD_DIR3)/.gcc3_3_build_hacks
	mkdir -p $(GCC_BUILD_DIR3)
	(cd $(GCC_BUILD_DIR3); ln -fs $(ARCH)-linux build-$(GNU_TARGET_NAME))
	(cd $(GCC_BUILD_DIR3); \
		$(TARGET_GCC_ARGS) \
		AR_FOR_BUILD=ar \
		AS_FOR_BUILD=as \
		LD_FOR_BUILD=ld \
		NM_FOR_BUILD=nm \
		RANLIB_FOR_BUILD=ranlib \
		HOST_CC=$(HOSTCC) \
		CC_FOR_BUILD=$(HOSTCC) \
		GCC_FOR_BUILD=$(HOSTCC) \
		CXX_FOR_BUILD=$(HOSTCC) \
		AR_FOR_TARGET=$(TARGET_CROSS)ar \
		AS_FOR_TARGET=$(TARGET_CROSS)as \
		LD_FOR_TARGET=$(TARGET_CROSS)ld \
		NM_FOR_TARGET=$(TARGET_CROSS)nm \
		CC_FOR_TARGET=$(TARGET_CROSS)gcc \
		GCC_FOR_TARGET=$(TARGET_CROSS)gcc \
		CXX_FOR_TARGET=$(TARGET_CROSS)g++ \
		RANLIB_FOR_TARGET=$(TARGET_CROSS)ranlib \
		./configure \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_TARGET_NAME) \
		--build=$(ARCH)-linux \
		--prefix=/usr \
		--mandir=/usr/man \
		--infodir=/usr/info \
		--with-gxx-include-dir=/usr/include/c++/3.3 \
		--enable-shared \
		$(MULTILIB) \
		--enable-target-optspace $(DISABLE_NLS) \
		--with-gnu-ld --disable-__cxa_atexit \
		--enable-languages=$(TARGET_LANGUAGES) \
		$(EXTRA_GCC_CONFIG_OPTIONS) \
	);
	touch $(GCC_BUILD_DIR3)/.configured
#Fixme -- for locale handling?
#ifeq ($(ENABLE_LOCALE),true)
#		--enable-clocale=gnu \
#endif

$(GCC_BUILD_DIR3)/.compiled: $(GCC_BUILD_DIR3)/.configured
	$(MAKE) -C $(GCC_BUILD_DIR3) \
		$(TARGET_GCC_ARGS) \
		AR_FOR_BUILD=ar \
		AS_FOR_BUILD=as \
		LD_FOR_BUILD=ld \
		NM_FOR_BUILD=nm \
		RANLIB_FOR_BUILD=ranlib \
		HOST_CC=$(HOSTCC) \
		CC_FOR_BUILD=$(HOSTCC) \
		GCC_FOR_BUILD=$(HOSTCC) \
		CXX_FOR_BUILD=$(HOSTCC) \
		AR_FOR_TARGET=$(TARGET_CROSS)ar \
		AS_FOR_TARGET=$(TARGET_CROSS)as \
		LD_FOR_TARGET=$(TARGET_CROSS)ld \
		NM_FOR_TARGET=$(TARGET_CROSS)nm \
		CC_FOR_TARGET=$(TARGET_CROSS)gcc \
		GCC_FOR_TARGET=$(TARGET_CROSS)gcc \
		CXX_FOR_TARGET=$(TARGET_CROSS)g++ \
		RANLIB_FOR_TARGET=$(TARGET_CROSS)ranlib
	touch $(GCC_BUILD_DIR3)/.compiled

$(TARGET_DIR)/usr/bin/gcc: $(GCC_BUILD_DIR3)/.compiled
	$(MAKE) -C $(GCC_BUILD_DIR3) \
		$(TARGET_GCC_ARGS) \
		AR_FOR_BUILD=ar \
		AS_FOR_BUILD=as \
		LD_FOR_BUILD=ld \
		NM_FOR_BUILD=nm \
		RANLIB_FOR_BUILD=ranlib \
		HOST_CC=$(HOSTCC) \
		CC_FOR_BUILD=$(HOSTCC) \
		GCC_FOR_BUILD=$(HOSTCC) \
		CXX_FOR_BUILD=$(HOSTCC) \
		AR_FOR_TARGET=$(TARGET_CROSS)ar \
		AS_FOR_TARGET=$(TARGET_CROSS)as \
		LD_FOR_TARGET=$(TARGET_CROSS)ld \
		NM_FOR_TARGET=$(TARGET_CROSS)nm \
		CC_FOR_TARGET=$(TARGET_CROSS)gcc \
		GCC_FOR_TARGET=$(TARGET_CROSS)gcc \
		CXX_FOR_TARGET=$(TARGET_CROSS)g++ \
		RANLIB_FOR_TARGET=$(TARGET_CROSS)ranlib \
		DESTDIR=$(TARGET_DIR) install
	(cd $(TARGET_DIR)/usr/bin; ln -fs gcc cc)
	(cd $(TARGET_DIR)/lib; ln -fs /usr/bin/cpp)
	rm -rf $(TARGET_DIR)/usr/$(GNU_TARGET_NAME)/include
	rm -rf $(TARGET_DIR)/usr/$(GNU_TARGET_NAME)/sys-include
	rm -rf $(TARGET_DIR)/usr/include/include $(TARGET_DIR)/usr/usr
	#-cp -dpf $(STAGING_DIR)/lib/libgcc* $(TARGET_DIR)/lib/
	#-chmod a-x $(STAGING_DIR)/lib/*++*
	#-cp -a $(STAGING_DIR)/lib/*++* $(TARGET_DIR)/lib/
	#-cp -a $(STAGING_DIR)/include/c++ $(TARGET_DIR)/usr/include/
	-mv $(TARGET_DIR)/lib/*.a $(TARGET_DIR)/usr/lib/
	-mv $(TARGET_DIR)/lib/*.la $(TARGET_DIR)/usr/lib/
	rm -f $(TARGET_DIR)/lib/libstdc++.so
	-(cd $(TARGET_DIR)/usr/lib; ln -fs /lib/libstdc++.so.5.0.5 libstdc++.so)
	# A nasty hack to work around g++ adding -lgcc_eh to the link
	-(cd $(TARGET_DIR)/usr/lib/gcc-lib/$(ARCH)-linux/$(GCC_VERSION)/ ; ln -s libgcc.a libgcc_eh.a)
	# Make sure gcc does not think we are cross compiling
	perl -i -p -e "s/^1/0/;" $(TARGET_DIR)/usr/lib/gcc-lib/$(ARCH)-linux/$(GCC_VERSION)/specs
	-(cd $(TARGET_DIR)/bin; find -type f | xargs $(STRIP) > /dev/null 2>&1)
	-(cd $(TARGET_DIR)/usr/bin; find -type f | xargs $(STRIP) > /dev/null 2>&1)
	rm -f $(TARGET_DIR)/usr/lib/*.la*
	rm -rf $(TARGET_DIR)/share/locale $(TARGET_DIR)/usr/info \
		$(TARGET_DIR)/usr/man $(TARGET_DIR)/usr/share/doc
	touch -c $(TARGET_DIR)/usr/bin/gcc

gcc3_3_target: uclibc_target binutils_target $(TARGET_DIR)/usr/bin/gcc

gcc3_3_target-clean:
	rm -rf $(GCC_BUILD_DIR3)
	rm -f $(TARGET_DIR)/bin/$(GNU_TARGET_NAME)*

gcc3_3_target-dirclean:
	rm -rf $(GCC_BUILD_DIR3)

endif
