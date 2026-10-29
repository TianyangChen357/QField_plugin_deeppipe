#!/usr/bin/env python3
"""Package the committed, editable QField project without requiring QGIS."""

from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile


def package_template(root: Path) -> tuple[Path, Path]:
    source = root / "project-template"
    metadata = json.loads((source / "template.json").read_text(encoding="utf-8"))
    version = metadata["template_version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("template_version must be a semantic version")
    project_file = metadata["project_file"]
    if not (source / project_file).is_file():
        raise ValueError("The template project file is missing")

    # Exclude provider journals, QGIS backup files, and local editor artifacts.
    # The committed project is closed and its GeoPackage is the complete data.
    allowed = {".qgs", ".qgz", ".gpkg", ".geojson", ".json", ".md", ".png", ".svg"}
    files = sorted(path for path in source.rglob("*") if path.is_file() and path.suffix in allowed)
    projects = [path for path in files if path.suffix in {".qgs", ".qgz"}]
    if projects != [source / project_file]:
        raise ValueError("QField automatic opening requires exactly one project in the ZIP")
    for path in files:
        if path.is_symlink():
            raise ValueError(f"Template files must be self-contained: {path}")
    output = root / "dist"
    output.mkdir(exist_ok=True)
    versioned = output / f"deeppipe-qfield-template-v{version}.zip"
    latest = output / "deeppipe-qfield-template-latest.zip"
    with zipfile.ZipFile(versioned, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            # Repeated packaging of identical source produces identical bytes.
            info = zipfile.ZipInfo(path.relative_to(source).as_posix(), (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    shutil.copyfile(versioned, latest)
    with zipfile.ZipFile(latest) as archive:
        if archive.testzip() is not None:
            raise ValueError("The project ZIP failed its integrity check")
    print(versioned)
    print(latest)
    print(f"SHA256 {hashlib.sha256(latest.read_bytes()).hexdigest()}")
    return versioned, latest


if __name__ == "__main__":
    package_template(Path(__file__).resolve().parents[1])
