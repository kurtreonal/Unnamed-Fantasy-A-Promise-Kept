"""Install pinned Godot CI tools from official GitHub release assets."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import urllib.error
import urllib.request
import zipfile

VERSION = "4.6.2"
API = "https://api.github.com/repos/godotengine/godot-builds/releases"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def api_headers(binary=False):
    headers = {"User-Agent": "UnnamedFantasyBuild", "Accept": "application/octet-stream" if binary else "application/vnd.github+json"}
    if os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    return headers


def asset_url(asset):
    request = urllib.request.Request(asset["url"], headers=api_headers(True))
    try:
        urllib.request.build_opener(NoRedirect).open(request, timeout=60)
    except urllib.error.HTTPError as error:
        if error.code == 302 and error.headers.get("Location", "").startswith("https://"):
            return error.headers["Location"]
        raise RuntimeError(f"Cannot resolve official asset {asset['name']}: HTTP {error.code}") from None
    raise RuntimeError("Expected an official asset download redirect")


class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.pos = url, size, 0
        self.tail_start = max(0, size - 65536)
        self.tail = self._range(self.tail_start, size - 1)

    def _range(self, first, last):
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={first}-{last}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Official asset server did not honor the byte range")
            return response.read()

    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.size + offset
        return self.pos

    def read(self, size=-1):
        size = min(size if size >= 0 else self.size - self.pos, self.size - self.pos)
        if size <= 0:
            return b""
        data = self.tail[self.pos - self.tail_start:self.pos - self.tail_start + size] if self.pos >= self.tail_start else self._range(self.pos, self.pos + size - 1)
        self.pos += len(data)
        return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["web", "android"], required=True)
    parser.add_argument("--destination", type=Path, default=Path(os.environ.get("RUNNER_TEMP", ".godot")) / "godot-ci")
    args = parser.parse_args()
    request = urllib.request.Request(f"{API}/tags/{VERSION}-stable", headers=api_headers())
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)
    assets = {asset["name"]: asset for asset in release["assets"]}
    args.destination.mkdir(parents=True, exist_ok=True)
    name = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
    engine_asset = assets[name]
    archive = args.destination / name
    print("Downloading official Godot Linux editor", flush=True)
    with urllib.request.urlopen(asset_url(engine_asset), timeout=120) as source, archive.open("wb") as target:
        shutil.copyfileobj(source, target, 1024 * 1024)
    digest = engine_asset.get("digest", "")
    if digest.startswith("sha256:"):
        with archive.open("rb") as file:
            assert hashlib.file_digest(file, "sha256").hexdigest() == digest[7:], "Godot archive checksum mismatch"
    with zipfile.ZipFile(archive) as zipped:
        zipped.extractall(args.destination)
    binary = args.destination / name.removesuffix(".zip")
    binary.chmod(0o755)
    template_asset = assets[f"Godot_v{VERSION}-stable_export_templates.tpz"]
    templates = Path.home() / ".local/share/godot/export_templates" / f"{VERSION}.stable"
    templates.mkdir(parents=True, exist_ok=True)
    names = ["web_nothreads_debug.zip", "web_nothreads_release.zip"] if args.platform == "web" else ["android_debug.apk", "android_release.apk"]
    with zipfile.ZipFile(RemoteZip(asset_url(template_asset), template_asset["size"])) as zipped:
        for template in names:
            print("Installing official template:", template, flush=True)
            with zipped.open("templates/" + template) as source, (templates / template).open("wb") as target:
                shutil.copyfileobj(source, target, 1024 * 1024)
    if os.environ.get("GITHUB_PATH"):
        with open(os.environ["GITHUB_PATH"], "a", encoding="utf-8") as file:
            file.write(str(binary.resolve().parent) + "\n")
        (args.destination / "godot").symlink_to(binary.resolve())
    print("Godot", VERSION, "and", args.platform, "templates ready", flush=True)


if __name__ == "__main__":
    main()
