#!/usr/bin/env python3
"""Exercise the recovery guard with isolated files and mocked Android properties."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

TREE = Path(__file__).resolve().parents[1]
SCRIPT = TREE / 'recovery/root/system/bin/resyncapex.sh'
SH = shutil.which('sh')


class KeyMintGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.props = self.root / 'props'
        self.props.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, code in {
            'getprop': 'cat "$TEST_PROPS/$1" 2>/dev/null || true\n',
            'setprop': 'printf "%s\\n" "$2" > "$TEST_PROPS/$1"\n',
        }.items():
            p = self.bin / name
            p.write_text('#!' + SH + '\n' + code)
            p.chmod(0o755)
        self.system = self.root / 'system_root/system/build.prop'
        self.vendor = self.root / 'vendor/build.prop'
        self.system.parent.mkdir(parents=True)
        self.vendor.parent.mkdir(parents=True)
        self.system.write_text('ro.build.version.release=17\nro.build.version.security_patch=2026-10-01\n')
        self.vendor.write_text('ro.vendor.build.security_patch=2026-06-01\n')
        self.mounts = self.root / 'mounts'
        self.mounts.write_text(f'dm-1 {self.root}/system_root erofs ro 0 0\ndm-3 {self.root}/vendor erofs ro 0 0\n')
        for k, v in {'twrp.avr.keymint.boot_release': '17',
                     'twrp.avr.keymint.boot_patch': '2026-10-01',
                     'twrp.avr.keymint.boot_vendor_patch': '2026-06-01',
                     'ro.build.version.release': '17',
                     'ro.build.version.security_patch': '2026-10-01',
                     'ro.vendor.build.security_patch': '2026-10-01'}.items():
            self.prop(k, v)
        script = SCRIPT.read_text()
        for old, new in [('/system_root', str(self.root / 'system_root')),
                         ('/vendor/build.prop', str(self.vendor)),
                         ('mounted /vendor', 'mounted ' + str(self.vendor.parent)),
                         ('/proc/mounts', str(self.mounts)),
                         ('/tmp/recovery.log', str(self.root / 'recovery.log')),
                         ('/dev/kmsg', str(self.root / 'kmsg'))]:
            script = script.replace(old, new)
        self.script = self.root / 'guard.sh'
        self.script.write_text(script)

    def prop(self, k, v):
        (self.props / k).write_text(v + '\n')

    def run_guard(self, expected):
        env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'], TEST_PROPS=str(self.props))
        result = subprocess.run([SH, str(self.script)], env=env, capture_output=True, text=True)
        self.assertEqual((self.props / 'twrp.avr.keymint_env').read_text().strip(), expected, result.stderr)
        self.assertEqual(result.returncode, 0 if expected == 'ok' else 1, result.stderr)
        if expected == 'ok':
            self.assertFalse((self.props / 'ctl.stop').exists())
        else:
            self.assertEqual((self.props / 'ctl.stop').read_text().strip(), 'vendor.keymint')

    def test_cos_matches_despite_late_vendor_property_spoof(self):
        self.run_guard('ok')

    def test_old_hal_snapshot_is_rejected_despite_updated_public_properties(self):
        self.prop('twrp.avr.keymint.boot_release', '16')
        self.prop('twrp.avr.keymint.boot_patch', '2026-06-01')
        self.run_guard('mismatch')

    def test_system_ota_is_rejected(self):
        self.system.write_text('ro.build.version.release=17\nro.build.version.security_patch=2026-11-01\n')
        self.run_guard('mismatch')

    def test_vendor_mismatch_is_rejected(self):
        self.vendor.write_text('ro.vendor.build.security_patch=2026-10-01\n')
        self.run_guard('mismatch')

    def test_missing_property_is_rejected(self):
        self.vendor.write_text('')
        self.run_guard('unknown')

    def test_missing_snapshot_is_rejected(self):
        (self.props / 'twrp.avr.keymint.boot_release').unlink()
        self.run_guard('unknown')

    def test_unmounted_vendor_cannot_reuse_old_ok_result(self):
        self.prop('twrp.avr.keymint_env', 'ok')
        self.mounts.write_text(f'dm-1 {self.root}/system_root erofs ro 0 0\n')
        self.run_guard('unknown')

    def test_fallback_system_build_prop(self):
        self.system.rename(self.root / 'system_root/build.prop')
        self.run_guard('ok')

    def test_property_names_are_matched_literally(self):
        self.vendor.write_text('roXvendorXbuildXsecurity_patch=2026-06-01\n')
        self.run_guard('unknown')

    def test_crlf_properties(self):
        self.vendor.write_bytes(b'ro.vendor.build.security_patch=2026-06-01\r\n')
        self.run_guard('ok')


if __name__ == '__main__':
    unittest.main(verbosity=2)
