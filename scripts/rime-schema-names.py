# SPDX-License-Identifier: GPL-3.0-only

import json
import os
from pathlib import Path
import sys

try:
    import yaml
except ModuleNotFoundError as error:
    if error.name != "yaml":
        raise
    yaml = None


def schema_name(schema_id, directories):
    if yaml is None:
        return schema_id

    filename = Path(f"{schema_id}.schema.yaml")
    if filename.name != str(filename):
        return schema_id

    for directory in directories:
        try:
            with (directory / filename).open(encoding="utf-8") as file:
                config = yaml.safe_load(file)
        except (OSError, UnicodeError, yaml.YAMLError):
            continue
        schema = config.get("schema") if isinstance(config, dict) else None
        name = schema.get("name") if isinstance(schema, dict) else None
        if isinstance(name, str) and name:
            return name
    return schema_id


user_data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
rime_data = user_data / "fcitx5/rime"
shared_data = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
directories = [rime_data / "build", rime_data]
for directory in filter(None, shared_data.split(":")):
    rime_data = Path(directory) / "rime-data"
    directories.extend([rime_data / "build", rime_data])

current = sys.argv[1]
schema_ids = json.load(sys.stdin)
schemas = [{"id": schema_id, "name": schema_name(schema_id, directories)} for schema_id in schema_ids]
schemas.sort(key=lambda schema: schema["id"] != current)
print(json.dumps({"current": current, "schemas": schemas}, ensure_ascii=False))
