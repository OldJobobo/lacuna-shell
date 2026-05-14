#!/usr/bin/env python3
import json
import os
from pathlib import Path


def app_dirs():
    dirs = []
    data_home = os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))
    dirs.append(Path(data_home) / "applications")
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    dirs.extend(Path(p) / "applications" for p in data_dirs.split(":") if p)
    return dirs


def read_desktop(path):
    values = {}
    in_entry = False
    try:
        for raw in path.read_text(errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                in_entry = line == "[Desktop Entry]"
                continue
            if not in_entry or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if "[" in key:
                continue
            values.setdefault(key, value)
    except OSError:
        return None
    return values


def category_for(app):
    cats = set(filter(None, app.get("Categories", "").split(";")))
    name = app["Name"].lower()
    text = " ".join([name, app.get("GenericName", "").lower(), app.get("Comment", "").lower()])

    if "Game" in cats or any(word in text for word in ["steam", "lutris", "heroic", "proton", "wine"]):
        return "games"
    if "Development" in cats:
        return "development"
    if "Network" in cats:
        return "internet"
    if "AudioVideo" in cats or "Audio" in cats or "Video" in cats:
        return "media"
    if "Graphics" in cats:
        return "graphics"
    if "Office" in cats:
        return "office"
    if "System" in cats or "Settings" in cats:
        return "system"
    if "Utility" in cats:
        return "utilities"
    return "other"


def main():
    seen = set()
    apps = []

    for directory in app_dirs():
        if not directory.is_dir():
            continue
        for path in sorted(directory.rglob("*.desktop")):
            desktop_id = path.name[:-8]
            if desktop_id in seen:
                continue
            entry = read_desktop(path)
            if not entry:
                continue
            if entry.get("Type", "Application") != "Application":
                continue
            if entry.get("NoDisplay", "").lower() == "true" or entry.get("Hidden", "").lower() == "true":
                continue
            if not entry.get("Name") or not entry.get("Exec"):
                continue

            seen.add(desktop_id)
            app = {
                "id": desktop_id,
                "Name": entry["Name"],
                "GenericName": entry.get("GenericName", ""),
                "Comment": entry.get("Comment", ""),
                "Icon": entry.get("Icon", ""),
                "Categories": entry.get("Categories", ""),
            }
            app["category"] = category_for(app)
            apps.append(app)

    apps.sort(key=lambda a: a["Name"].casefold())
    print(json.dumps(apps, separators=(",", ":")))


if __name__ == "__main__":
    main()
