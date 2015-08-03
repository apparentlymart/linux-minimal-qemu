
# In this Makefile we assume in a few spots an x86_64 system.
# With some modifications it's likely possible to use this for
# other targets, but the author has not attempted this.

# This supports only the 4.x line of kernels without modification
# due to the URL scheme used at kernel.org. You can modify this
# Makefile or manually download an archive to use other versions.

LINUX_VERSION=4.1.3
BUSYBOX_VERSION=1.23.2
ARCH=x86_64
OUT=out
MAKE_OPTS=-j4

all: linux initramfs

boot: all
	qemu-system-$(ARCH) -kernel out/linux/arch/$(ARCH)/boot/bzImage -initrd out/initramfs.cpio.gz -nographic -append "console=ttyS0"

linux: out/linux/arch/$(ARCH)/boot/bzImage

initramfs: out/initramfs.cpio.gz

busybox: out/busybox/_install/bin/busybox

out/linux/.config: src/linux-$(LINUX_VERSION)/Makefile
	cd src/linux-$(LINUX_VERSION) && make O=../../out/linux x86_64_defconfig
	cd src/linux-$(LINUX_VERSION) && make O=../../out/linux kvmconfig

out/linux/arch/$(ARCH)/boot/bzImage: out/linux/.config
	cd out/linux && make $(MAKE_OPTS)

src/linux-$(LINUX_VERSION).tar.xz:
	wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-$(LINUX_VERSION).tar.xz -O $@

src/linux-$(LINUX_VERSION)/Makefile: src/linux-$(LINUX_VERSION).tar.xz
	tar xvf $< -C src
	touch $@

out/busybox/.config: src/busybox-$(BUSYBOX_VERSION)/Makefile
	mkdir -pv out/busybox
	cd src/busybox-$(BUSYBOX_VERSION) && make O=../../out/busybox defconfig
	echo "CONFIG_STATIC=y" >>$@

out/busybox/busybox: out/busybox/.config
	cd out/busybox && make $(MAKE_OPTS)

out/busybox/_install/bin/busybox: out/busybox/busybox
	cd out/busybox && make install

src/busybox-$(BUSYBOX_VERSION).tar.bz2:
	mkdir -p src
	wget http://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2 -O $@

src/busybox-$(BUSYBOX_VERSION)/Makefile: src/busybox-$(BUSYBOX_VERSION).tar.bz2
	tar xvf $< -C src
	touch $@

out/initramfs/init: src/init
	mkdir -pv out/initramfs
	cp $< $@
	chmod a+x $@

out/initramfs/bin/busybox: out/busybox/_install/bin/busybox
	mkdir -pv out/initramfs
	mkdir -pv out/initramfs/bin
	mkdir -pv out/initramfs/sbin
	mkdir -pv out/initramfs/etc
	mkdir -pv out/initramfs/proc
	mkdir -pv out/initramfs/sys
	mkdir -pv out/initramfs/dev
	mkdir -pv out/initramfs/tmp
	mkdir -pv out/initramfs/usr/bin
	mkdir -pv out/initramfs/usr/sbin
	cp -av out/busybox/_install/* out/initramfs

out/initramfs.cpio.gz: out/initramfs/init out/initramfs/bin/busybox
	cd out/initramfs && find . -print0 | cpio --null -ov --format=newc | gzip -9 >../initramfs.cpio.gz

.PHONY: linux busybox initramfs boot all

