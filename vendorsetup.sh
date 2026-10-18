#
# OrangeFox build settings for motorola avr (XT2611).
# Sourced by build/envsetup.sh; only acts when building avr.
#
if [ "$FOX_BUILD_DEVICE" = "avr" ] || [ "$1" = "avr" ]; then
	# Virtual A/B (ro.virtual_ab.enabled=true, compression + userspace snapshots)
	export FOX_VIRTUAL_AB_DEVICE=1
	export FOX_USE_BASH_SHELL=1
	export FOX_USE_NANO_EDITOR=1
	export FOX_USE_TAR_BINARY=1
	export FOX_USE_SED_BINARY=1
fi
