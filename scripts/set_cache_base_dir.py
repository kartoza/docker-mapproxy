#!/usr/bin/env python3
"""Set globals.cache.base_dir without reformatting the MapProxy YAML file."""

import json
import re
import sys
from pathlib import Path


def set_cache_base_dir(config_path: Path, cache_dir: str, overwrite: bool = False) -> str:
    lines = config_path.read_text(encoding="utf-8").splitlines(keepends=True)
    value = json.dumps(cache_dir)
    globals_index = next(
        (index for index, line in enumerate(lines) if re.match(r"^globals:\s*(?:#.*)?$", line.rstrip("\n"))),
        None,
    )

    if globals_index is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        lines.extend(["globals:\n", "  cache:\n", f"    base_dir: {value}\n"])
    else:
        section_end = next(
            (
                index
                for index in range(globals_index + 1, len(lines))
                if lines[index].strip() and not lines[index].startswith((" ", "\t", "#"))
            ),
            len(lines),
        )
        cache_index = next(
            (
                index
                for index in range(globals_index + 1, section_end)
                if re.match(r"^  cache:\s*(?:#.*)?$", lines[index].rstrip("\n"))
            ),
            None,
        )
        if cache_index is None:
            lines.insert(globals_index + 1, "  cache:\n")
            lines.insert(globals_index + 2, f"    base_dir: {value}\n")
        else:
            cache_end = next(
                (
                    index
                    for index in range(cache_index + 1, section_end)
                    if lines[index].strip() and not lines[index].startswith(("    ", "\t", "#"))
                ),
                section_end,
            )
            base_dir_index = next(
                (
                    index
                    for index in range(cache_index + 1, cache_end)
                    if re.match(r"^    base_dir:\s*", lines[index])
                ),
                None,
            )
            if base_dir_index is None:
                lines.insert(cache_index + 1, f"    base_dir: {value}\n")
            else:
                if not overwrite:
                    return "preserved existing globals.cache.base_dir"
                lines[base_dir_index] = f"    base_dir: {value}\n"

    config_path.write_text("".join(lines), encoding="utf-8")
    return f"set globals.cache.base_dir to {cache_dir}"


if __name__ == "__main__":
    overwrite = "--overwrite" in sys.argv[1:]
    arguments = [argument for argument in sys.argv[1:] if argument != "--overwrite"]
    if len(arguments) != 2:
        raise SystemExit(
            f"usage: {sys.argv[0]} [--overwrite] CONFIG_FILE CACHE_DIR"
        )
    print(set_cache_base_dir(Path(arguments[0]), arguments[1], overwrite=overwrite))
