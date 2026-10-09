from pathlib import Path
import os
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parents[1]
INSTALL = HERE / 'fedora/install-fedora.sh'


class InstallerTests(unittest.TestCase):
    def test_syntax(self):
        subprocess.run(['bash', '-n', str(INSTALL)], check=True)

    def test_user_level_install_in_temp_home(self):
        if os.geteuid() == 0:
            self.skipTest('Installer rightly refuses to run as root')
        with tempfile.TemporaryDirectory() as home:
            data = Path(home) / '.local/share'
            env = dict(os.environ, HOME=home, XDG_DATA_HOME=str(data),
                       XDG_BIN_HOME=str(Path(home) / '.local/bin'))
            subprocess.run(['bash', str(INSTALL)], env=env, check=True, capture_output=True)
            self.assertTrue((data / 'rabbit-code-native/fedora/native_app.py').is_file())
            self.assertTrue((data / 'rabbit-code-native/rabbit_local.py').is_file())
            self.assertIn('Name=Rabbit Code Native',
                          (data / 'applications/rabbit-code-native.desktop').read_text())
            self.assertIn('exec python3',
                          (Path(home) / '.local/bin/rabbit-code-native').read_text())


if __name__ == '__main__':
    unittest.main()
