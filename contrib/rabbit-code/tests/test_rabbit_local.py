import contextlib
import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rabbit_local as app


class LocalFirstTests(unittest.TestCase):
    def setUp(self):
        self.tmp = TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name)

    def test_favors_preferred_local_model(self):
        self.assertEqual(app.selected_model(["qwen2.5-coder:7b", "qwen3:8b"], None), "qwen3:8b")

    def test_explicit_installed_model(self):
        self.assertEqual(app.selected_model(["llama3.1:8b"], "llama3.1:8b"), "llama3.1:8b")

    def test_no_unverified_default(self):
        with self.assertRaises(app.LocalError):
            app.selected_model(["new-model"], None)

    def test_missing_requested_model_fails_closed(self):
        with self.assertRaises(app.LocalError):
            app.selected_model(["qwen3:8b"], "remote/model")

    @patch.object(app, "installed_models", return_value=["qwen3:8b"])
    def test_init_generates_only_ollama(self, mock):
        with contextlib.redirect_stdout(io.StringIO()):
            app.init(self.project, None)
        data = json.loads(app.config_path(self.project).read_text())
        self.assertEqual(data["enabled_providers"], ["ollama"])
        self.assertEqual(data["model"], "ollama/qwen3:8b")
        self.assertEqual(app.read_config(self.project), "qwen3:8b")
        self.assertFalse((self.project / "kilo.jsonc").exists())

    @patch.object(app, "installed_models", return_value=["qwen3:8b"])
    def test_init_does_not_overwrite(self, mock):
        p = self.project / ".kilo"
        p.mkdir()
        (p / "kilo.jsonc").write_text("DO NOT CHANGE")
        with self.assertRaises(app.LocalError):
            app.init(self.project, None)
        self.assertEqual((p / "kilo.jsonc").read_text(), "DO NOT CHANGE")

    @patch.object(app, "installed_models", return_value=["qwen3:8b"])
    def test_init_rejects_symlink_dir(self, mock):
        real = self.project / "real"
        real.mkdir()
        (self.project / ".kilo").symlink_to(real, target_is_directory=True)
        with self.assertRaises(app.LocalError):
            app.init(self.project, None)

    def test_no_project_config_rejects_run(self):
        with self.assertRaises(app.LocalError):
            app.read_config(self.project)

    def test_non_ollama_provider_rejected(self):
        p = app.config_path(self.project)
        p.parent.mkdir()
        p.write_text(json.dumps({"model": "openai/gpt-x", "enabled_providers": ["openai"]}))
        with self.assertRaises(app.LocalError):
            app.read_config(self.project)

    @patch.object(app, "installed_models", return_value=[])
    def test_run_missing_model_fails(self, mock):
        p = app.config_path(self.project)
        p.parent.mkdir()
        p.write_text(json.dumps(app.project_config("qwen3:8b")))
        with self.assertRaises(app.LocalError):
            app.run(self.project, [])

    @patch.object(app, "installed_models", return_value=["qwen3:8b"])
    @patch.object(app.subprocess, "run")
    def test_run_launches_with_optout_and_correct_cwd(self, run, mock):
        p = app.config_path(self.project)
        p.parent.mkdir()
        p.write_text(json.dumps(app.project_config("qwen3:8b")))
        run.return_value.returncode = 0
        with patch.dict(os.environ, {"RABBIT_KILO_BIN": "/usr/local/bin/kilo"}):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(app.run(self.project, ["--help"]), 0)
        args, kwargs = run.call_args
        self.assertEqual(args[0], ["/usr/local/bin/kilo", "--help"])
        self.assertEqual(kwargs["cwd"], self.project)
        self.assertEqual(kwargs["env"]["KILO_TELEMETRY_LEVEL"], "off")

    @patch.object(app, "installed_models", side_effect=app.LocalError("offline"))
    def test_doctor_offline_does_not_create_files(self, mock):
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(app.main(["doctor", "--project", str(self.project)]), 2)
        self.assertEqual(list(self.project.iterdir()), [])

    @patch.object(app, "installed_models", return_value=["qwen3:8b"])
    def test_cli_init(self, mock):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(app.main(["init", "--project", str(self.project)]), 0)
        self.assertTrue(app.config_path(self.project).is_file())

    def test_project_model_config_has_no_api_keys(self):
        data = json.dumps(app.project_config("qwen3:8b"))
        self.assertNotIn("apiKey", data)
        self.assertNotIn("https://", data)
        self.assertNotIn("kilo gateway", data.lower())

if __name__ == "__main__":
    unittest.main()
