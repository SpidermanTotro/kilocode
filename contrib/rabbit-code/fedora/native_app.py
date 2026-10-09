#!/usr/bin/env python3
"""Rabbit Code Native: Fedora-host, local Ollama-only web UI.

Standard-library only. Binds 127.0.0.1, never contacts cloud providers, has
no shell/file-write/model-tool capabilities, and stores no conversations.
"""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import secrets
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, ProxyHandler, HTTPRedirectHandler, build_opener
import webbrowser

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from rabbit_local import LocalError, installed_models  # noqa: E402

OLLAMA_CHAT = "http://127.0.0.1:11434/api/chat"
MAX_REQUEST_BYTES = 120_000
MAX_RESPONSE_BYTES = 2_000_000
MAX_MESSAGES = 16
MAX_TEXT = 12_000


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def ask_ollama(model: str, history: list[dict[str, str]]) -> str:
    """Only the local Ollama API; force no proxy or HTTP redirects."""
    system = {"role": "system", "content": (
        "You are Rabbit Code, a local-only coding assistant. "
        "Give accurate, testable coding advice. You cannot read, edit, or execute files; "
        "never claim that you did."
    )}
    payload = json.dumps({"model": model, "stream": False, "messages": [system, *history]}).encode()
    req = Request(OLLAMA_CHAT, data=payload, headers={"Content-Type": "application/json"}, method="POST")
    client = build_opener(ProxyHandler({}), NoRedirect())
    with client.open(req, timeout=180) as reply:
        body = reply.read(MAX_RESPONSE_BYTES + 1)
    if len(body) > MAX_RESPONSE_BYTES:
        raise LocalError("Ollama response exceeded size limit")
    try:
        result = json.loads(body)
    except ValueError as error:
        raise LocalError("Ollama returned invalid JSON") from error
    message = result.get("message") if isinstance(result, dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, str):
        raise LocalError("Ollama did not return assistant message content")
    return content


def validate_chat(payload: object, models: list[str]) -> tuple[str, list[dict[str, str]]]:
    if not isinstance(payload, dict):
        raise LocalError("Expected JSON object")
    model = payload.get("model")
    if not isinstance(model, str) or model not in models:
        raise LocalError("Model is not installed in the local Ollama instance")
    history = payload.get("messages")
    if not isinstance(history, list) or not 1 <= len(history) <= MAX_MESSAGES:
        raise LocalError(f"Use 1 to {MAX_MESSAGES} messages")
    for msg in history:
        if not isinstance(msg, dict) or msg.get("role") not in ("user", "assistant"):
            raise LocalError("Messages must have only user/assistant roles")
        text = msg.get("content")
        if not isinstance(text, str) or not 0 < len(text) <= MAX_TEXT:
            raise LocalError(f"Message content must have 1 to {MAX_TEXT} characters")
    if history[-1]["role"] != "user":
        raise LocalError("Last message must be from user")
    return model, [{"role": msg["role"], "content": msg["content"]} for msg in history]


HTML = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rabbit Code — Native Fedora</title>
<style>
:root{color-scheme:dark;font:16px system-ui,sans-serif;background:#0b0d16;color:#e9ebff}
*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at top left,#222044 0,#0b0d16 46%)}
.shell{display:grid;grid-template-columns:260px minmax(0,1fr);height:100vh;min-height:520px}
aside{padding:28px 20px;background:#101222;border-right:1px solid #30344c;display:flex;flex-direction:column;gap:18px}
.brand{font-size:25px;font-weight:800;letter-spacing:-.06em}.brand span{color:#afa0ff}
.sub{color:#b8bacc;font-size:13px;line-height:1.5}.pill{padding:9px 12px;border:1px solid #447a65;background:#152c28;border-radius:10px;color:#a4e8c9;font-size:12px;font-weight:650}
label{font-size:12px;color:#b8bacc;display:block;margin-bottom:7px}
select,textarea{width:100%;background:#16192c;color:#e9ebff;border:1px solid #383b57;border-radius:12px;padding:12px;font:inherit}
select:focus,textarea:focus{outline:2px solid #8d80ee}
button{background:#8172ec;color:white;border:0;border-radius:12px;padding:12px 18px;cursor:pointer;font-weight:650}
button:hover{background:#9b8ffa}button:disabled{opacity:.5;cursor:wait}.secondary{background:#22253b;border:1px solid #353a56}
.note{margin-top:auto;font-size:12px;line-height:1.6;color:#9fa4b8}
main{min-width:0;display:flex;flex-direction:column;max-width:1040px;width:100%;margin:0 auto;padding:26px 30px}
header{display:flex;justify-content:space-between;gap:10px;align-items:center;border-bottom:1px solid #2c314b;padding-bottom:18px}
h1{font-size:23px;margin:0}.tiny{font-size:12px;color:#a6abc5}
#chat{flex:1;overflow:auto;display:flex;flex-direction:column;gap:15px;padding:25px 0}
.msg{max-width:90%;padding:15px 18px;border-radius:16px;white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.55;background:#1b2032;border:1px solid #333b55}
.msg.user{align-self:flex-end;background:#3c326d;border-color:#544494}.msg.assistant{align-self:flex-start}
.empty{margin:auto;color:#acb3d3;text-align:center;line-height:1.8}.empty strong{font-size:25px;color:#f3f0ff}
form{display:flex;gap:12px;align-items:end;border-top:1px solid #2c314b;padding-top:17px}
textarea{resize:vertical;min-height:62px;max-height:190px}.hint{font-size:11px;color:#7e859c;margin:9px 0 0}
@media(max-width:750px){.shell{display:flex;flex-direction:column;height:100dvh}aside{padding:12px;gap:8px}.note{display:none}main{min-height:0;padding:12px}#chat{padding:12px 0}.brand{font-size:19px}}
</style></head>
<body><div class="shell"><aside><div class="brand">🐇 Rabbit<span>Code</span></div>
<div class="sub">Our own Fedora-native, local-first coding interface.</div>
<div class="pill">● LOCAL OLLAMA ONLY</div><div><label for="model">Installed model</label><select id="model"><option>Loading…</option></select></div>
<button class="secondary" id="reload">Refresh models</button><button class="secondary" id="clear">Clear chat</button>
<div class="note">No accounts. No cloud inference. No automatic downloads, shell execution or file edits.<br><br>
This first release is a read-only assistant. Conversations are kept in this tab only.</div></aside>
<main><header><h1>Rabbit Code <span class="tiny">Native v0.1</span></h1><span class="tiny" id="status">Connecting to Ollama…</span></header>
<section id="chat" aria-live="polite"><div class="empty" id="welcome"><strong>Build with your own AI.</strong><br>Powered by the models already on your Fedora machine.<br>Ask a coding question to begin.</div></section>
<form id="form"><textarea id="prompt" placeholder="Ask your local model about code…" required maxlength="12000"></textarea><button id="send" type="submit">Send</button></form>
<p class="hint">Ctrl+Enter to send · Esc to clear input · Nothing is sent to a cloud model.</p></main></div>
<script nonce="__NONCE__">
const token='__TOKEN__',history=[],chat=document.getElementById('chat'),model=document.getElementById('model');
const status=document.getElementById('status'),send=document.getElementById('send'),prompt=document.getElementById('prompt');
function add(role,text){document.getElementById('welcome')?.remove();const el=document.createElement('div');el.className='msg '+role;el.textContent=text;chat.appendChild(el);chat.scrollTop=chat.scrollHeight;return el;}
async function load(){status.textContent='Checking local Ollama…';try{const r=await fetch('/api/models',{cache:'no-store'});const data=await r.json();if(!r.ok)throw Error(data.error||'Failed');model.replaceChildren(...data.models.map(name=>{const o=document.createElement('option');o.value=name;o.textContent=name;return o}));status.textContent=data.models.length+' local models available';if(!data.models.length)status.textContent='No local models installed';}catch(e){status.textContent='Ollama unavailable: '+e.message;model.replaceChildren();}}
document.getElementById('reload').onclick=load;
document.getElementById('clear').onclick=()=>{history.length=0;chat.replaceChildren();add('assistant','Chat cleared. Nothing was saved to disk.');};
document.getElementById('form').onsubmit=async e=>{e.preventDefault();const value=prompt.value.trim();if(!value||!model.value||send.disabled)return;prompt.value='';add('user',value);history.push({role:'user',content:value});while(history.length>14)history.splice(0,2);send.disabled=true;const answer=add('assistant','Thinking locally…');try{const r=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json','X-Rabbit-Token':token},body:JSON.stringify({model:model.value,messages:history})});const data=await r.json();if(!r.ok)throw Error(data.error||'Request failed');answer.textContent=data.reply;history.push({role:'assistant',content:data.reply.slice(0,12000)});}catch(e){answer.textContent='Local request failed: '+e.message;history.pop();}finally{send.disabled=false;prompt.focus();chat.scrollTop=chat.scrollHeight;}};
prompt.addEventListener('keydown',e=>{if(e.key==='Enter'&&e.ctrlKey){e.preventDefault();document.getElementById('form').requestSubmit();}if(e.key==='Escape')prompt.value='';});
load();
</script></body></html>'''


class RabbitServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int]):
        self.token = secrets.token_urlsafe(32)
        self.nonce = secrets.token_urlsafe(16)
        super().__init__(address, RabbitHandler)


class RabbitHandler(BaseHTTPRequestHandler):
    server: RabbitServer

    def log_message(self, format: str, *args: object) -> None:
        return

    def send(self, status: int, data: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Content-Security-Policy", (
            "default-src 'none'; style-src 'unsafe-inline'; "
            f"script-src 'nonce-{self.server.nonce}'; connect-src 'self'; "
            "form-action 'none'; frame-ancestors 'none'"
        ))
        self.end_headers()
        self.wfile.write(data)

    def respond(self, status: int, payload: dict) -> None:
        self.send(status, json.dumps(payload).encode("utf-8"), "application/json; charset=utf-8")

    def accepted_host(self) -> bool:
        return self.headers.get("Host") in (
            f"127.0.0.1:{self.server.server_port}",
            f"localhost:{self.server.server_port}",
        )

    def do_GET(self) -> None:
        if not self.accepted_host():
            return self.respond(403, {"error": "Invalid local Host"})
        if self.path == "/":
            html = HTML.replace("__TOKEN__", self.server.token).replace("__NONCE__", self.server.nonce)
            return self.send(200, html.encode("utf-8"), "text/html; charset=utf-8")
        if self.path == "/api/models":
            try:
                return self.respond(200, {"models": installed_models()})
            except LocalError as error:
                return self.respond(503, {"error": str(error)})
        return self.respond(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if not self.accepted_host():
            return self.respond(403, {"error": "Invalid local Host"})
        if self.path != "/api/chat":
            return self.respond(404, {"error": "Not found"})
        if self.headers.get("X-Rabbit-Token") != self.server.token:
            return self.respond(403, {"error": "Missing local session token"})
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
            return self.respond(415, {"error": "JSON only"})
        origin = self.headers.get("Origin")
        if origin not in (None, f"http://localhost:{self.server.server_port}",
                          f"http://127.0.0.1:{self.server.server_port}"):
            return self.respond(403, {"error": "Cross-origin requests denied"})
        try:
            count = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.respond(400, {"error": "Invalid Content-Length"})
        if not 0 < count <= MAX_REQUEST_BYTES:
            return self.respond(413, {"error": "Invalid request size"})
        try:
            data = json.loads(self.rfile.read(count))
            model, messages = validate_chat(data, installed_models())
            reply = ask_ollama(model, messages)
            return self.respond(200, {"reply": reply})
        except (ValueError, UnicodeDecodeError, LocalError) as error:
            return self.respond(400, {"error": str(error)})
        except (HTTPError, URLError, OSError, TimeoutError) as error:
            return self.respond(503, {"error": f"Local Ollama request failed: {error}"})


def main(argv: list[str] | None = None) -> int:
    cli = argparse.ArgumentParser(description="Rabbit Code Native — no Debian/Distrobox/Kilo required")
    cli.add_argument("--port", type=int, default=8766)
    cli.add_argument("--no-browser", action="store_true")
    args = cli.parse_args(argv)
    if not 0 <= args.port <= 65535:
        cli.error("port must be 0 to 65535")
    with RabbitServer(("127.0.0.1", args.port)) as server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print(f"Rabbit Code Native starting at {url}\nFedora host • localhost Ollama only • Ctrl+C exits", flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nRabbit Code stopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
