"""Configure Godot 4.6 Android export paths without storing signing secrets."""
import argparse
import json
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument("--java", required=True, type=Path)
parser.add_argument("--sdk", required=True, type=Path)
args = parser.parse_args()
java, sdk = args.java.resolve(), args.sdk.resolve()
executable_suffix = ".exe" if os.name == "nt" else ""
if not (java / "bin" / ("java" + executable_suffix)).is_file():
    parser.error("Java SDK does not contain bin/java")
if not (sdk / "platform-tools" / ("adb" + executable_suffix)).is_file():
    parser.error("Android SDK does not contain platform-tools/adb")
if os.name == "nt":
    config_root = Path(os.environ["APPDATA"]) / "Godot"
else:
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "godot"
settings = config_root / "editor_settings-4.6.tres"
config_root.mkdir(parents=True, exist_ok=True)
text = settings.read_text(encoding="utf-8") if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
for name, value in {"export/android/java_sdk_path": java, "export/android/android_sdk_path": sdk}.items():
    pattern = r"^" + re.escape(name) + r"\s*=.*$"
    line = name + " = " + json.dumps(value.as_posix())
    text = re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip() + "\n" + line + "\n"
settings.write_text(text, encoding="utf-8")
print("Configured Godot Android export SDK paths.")
