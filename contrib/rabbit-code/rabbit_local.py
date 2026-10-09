#!/usr/bin/env python3
"""Rabbit Code: opt-in, project-scoped local Ollama adapter for the Kilo CLI.

No dependencies outside the Python standard library. No automatic model pulls,
cloud provider fallback, global config edits, or uploads.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request

OLLAMA_TAGS = "http://127.0.0.1:11434/api/tags"
PREFERRED_MODELS = ("qwen3:8b", "qwen2.5-coder:7b")
CONFIG_RELATIVE = Path(".kilo/kilo.jsonc")


class LocalError(Exception):
    """A recoverable, user-facing configuration or connectivity problem."""


def installed_models() -> list[str]:
    """Ask ONLY the local Ollama daemon; avoid proxies and redirects."""
    from urllib.request import build_opener, ProxyHandler, HTTPRedirectHandler

    class NoRedirect(HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    request = Request(OLLAMA_TAGS, headers={"Accept": "application/json"})
    opener = build_opener(ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=3) as response:
            body = response.read(2 * 1024 * 1024 + 1)
        if len(body) > 2 * 1024 * 1024:
            raise LocalError("Ollama model list unexpectedly large; refusing to parse")
        data = json.loads(body)
        if not isinstance(data, dict) or not isinstance(data.get("models"), list):
            raise ValueError("missing models list")
        models = data["models"]
        if any(not isinstance(item, dict) or not isinstance(item.get("name"), str) for item in models):
            raise ValueError("invalid model entry")
        return sorted({item["name"] for item in models})
    except (HTTPError, URLError, OSError, TimeoutError, ValueError, json.JSONDecodeError) as error:
        raise LocalError(f"Local Ollama is not ready at {OLLAMA_TAGS}: {error}") from error


def selected_model(available: list[str], requested: str | None) -> str:
    if requested:
        if requested not in available:
            raise LocalError(f"Model {requested!r} is not installed. Available: {', '.join(available) or '(none)'}")
        return requested
    for preferred in PREFERRED_MODELS:
        if preferred in available:
            return preferred
    raise LocalError("Choose an installed local model with --model; none of the tested defaults are installed")


def project_config(model: str) -> dict:
    return {
        "enabled_providers": ["ollama"],
        "model": "ollama/" + model,
        "provider": {"ollama": {"models": {model: {"name": model}}}},
    }


def valid_project(project: Path) -> Path:
    project = project.expanduser().resolve(strict=True)
    if not project.is_dir():
        raise LocalError(f"Not a project directory: {project}")
    return project


def config_path(project: Path) -> Path:
    return project / CONFIG_RELATIVE


def init(project: Path, model: str | None) -> None:
    available = installed_models()
    choice = selected_model(available, model)
    settings_dir = project / ".kilo"
    if settings_dir.is_symlink():
        raise LocalError(f"Refusing symlinked config directory: {settings_dir}")
    settings_dir.mkdir(mode=0o700, exist_ok=True)
    if not settings_dir.is_dir():
        raise LocalError(f"Not a directory: {settings_dir}")
    path = config_path(project)
    contents = json.dumps(project_config(choice), indent=2, ensure_ascii=False) + "\n"
    try:
        fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError as error:
        raise LocalError(f"Configuration already exists; no changes made: {path}") from error
    with os.fdopen(fd, "w", encoding="utf-8") as target:
        target.write(contents)
    print(f"Rabbit Code local project prepared: {path}")
    print(f"Only enabled provider: ollama; selected installed model: {choice}")
    print("No global settings, existing configuration, or model weights modified.")


def read_config(project: Path) -> str:
    path = config_path(project)
    if not path.is_file():
        raise LocalError("Project has no .kilo/kilo.jsonc; run 'init' first")
    try:
        config = json.loads(path.read_text(encoding="utf-8"))
        if config.get("enabled_providers") != ["ollama"]:
            raise ValueError("enabled_providers must be exactly ['ollama']")
        model = config.get("model")
        if not isinstance(model, str) or not model.startswith("ollama/") or len(model) <= 7:
            raise ValueError("model must specify ollama/<installed-model>")
        if model[7:] not in config.get("provider", {}).get("ollama", {}).get("models", {}):
            raise ValueError("selected model missing from local model registry")
        return model[7:]
    except (OSError, UnicodeError, ValueError, TypeError, AttributeError) as error:
        raise LocalError(f"Invalid local-only project config at {path}: {error}") from error


def run(project: Path, extra: list[str]) -> int:
    model = read_config(project)
    if model not in installed_models():
        raise LocalError(f"Selected local model {model!r} is unavailable; refusing cloud fallback")
    kilo = os.environ.get("RABBIT_KILO_BIN") or shutil.which("kilo")
    if not kilo:
        raise LocalError("Kilo CLI not found. Install the CLI or set RABBIT_KILO_BIN to its executable path")
    env = dict(os.environ)
    env["KILO_TELEMETRY_LEVEL"] = "off"  # Kilo CLI, not all Desktop components
    print(f"Starting Rabbit Code local adapter (ollama/{model}); CLI telemetry requested off", flush=True)
    return subprocess.run([kilo, *extra], cwd=project, env=env, check=False).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Rabbit Code local-only project adapter (Kilo CLI compatible)")
    parser.add_argument("command", choices=("doctor", "init", "run"))
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--model", help="Exact locally installed Ollama model ID (init only)")
    args, trailing = parser.parse_known_args(argv)
    if args.command != "run" and trailing:
        parser.error("unexpected arguments: " + " ".join(trailing))
    try:
        project = valid_project(args.project)
        if args.command == "doctor":
            names = installed_models()
            print(f"Ollama responds on {OLLAMA_TAGS}")
            print("Installed local models: " + (", ".join(names) if names else "(none)"))
            print("Project preset: " + (str(config_path(project)) if config_path(project).exists() else "not initialized"))
            return 0
        if args.command == "init":
            init(project, args.model)
            return 0
        if args.model:
            raise LocalError("--model is only valid for init")
        return run(project, trailing[1:] if trailing[:1] == ["--"] else trailing)
    except LocalError as error:
        print(f"Rabbit Code: {error}", file=sys.stderr)
        return 2
    except OSError as error:
        print(f"Rabbit Code: OS error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
