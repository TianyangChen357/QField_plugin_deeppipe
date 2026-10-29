#!/usr/bin/env python3
"""Build the editable QField project with native PyQGIS (QGIS 3.40+).

The input must be the Portal's WGS84 Raleigh 50-node sample, or the normalized
WGS84 fixture committed in project-template/data/inlets.geojson. The generated
GeoPackage is the editable project data; the GeoJSON remains an immutable
sample/provenance fixture and is never loaded as a second editable layer.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import uuid

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qgis.PyQt.QtCore import QMetaType
from qgis.PyQt.QtGui import QColor, QFont
from qgis.core import (
    QgsApplication,
    Qgis,
    QgsCoordinateReferenceSystem,
    QgsCoordinateTransform,
    QgsDefaultValue,
    QgsEditorWidgetSetup,
    QgsFeature,
    QgsField,
    QgsFieldConstraints,
    QgsGeometry,
    QgsMarkerSymbol,
    QgsPalLayerSettings,
    QgsPointXY,
    QgsProject,
    QgsRasterLayer,
    QgsReferencedRectangle,
    QgsTextBufferSettings,
    QgsTextFormat,
    QgsVectorFileWriter,
    QgsVectorLayer,
    QgsVectorLayerSimpleLabeling,
)


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "project-template"
PROJECT_FILE = "DeepPipe_Mobile_Demo.qgs"
TEMPLATE_VERSION = "1.0.0"
SOURCE = "Raleigh.gpkg / Inlets"


def normalized_nodes(source: Path) -> dict:
    collection = json.loads(source.read_text())
    features = collection.get("features", [])
    if collection.get("type") != "FeatureCollection" or len(features) != 50:
        raise ValueError("The template requires the same 50-node Portal fixture.")
    normalized = []
    seen = set()
    for feature in features:
        properties = feature.get("properties", {})
        source_id = str(properties.get("ID", properties.get("source_id", "")))
        if not source_id or source_id in seen:
            raise ValueError("Every sample node needs a unique source ID.")
        seen.add(source_id)
        geometry = feature.get("geometry", {})
        coords = geometry.get("coordinates", [])
        if geometry.get("type") != "Point" or len(coords) != 2:
            raise ValueError("The sample must contain WGS84 Point geometries.")
        if not (-180 <= coords[0] <= 180 and -90 <= coords[1] <= 90):
            raise ValueError("The sample coordinates must be WGS84 longitude/latitude.")
        inlet_uuid = str(uuid.uuid5(uuid.NAMESPACE_URL, "deeppipe:raleigh-50:" + source_id))
        normalized.append({
            "type": "Feature",
            "id": source_id,
            "properties": {
                "node_id": source_id,
                "source_id": source_id,
                "inlet_uuid": inlet_uuid,
                "status": "sample",
                "notes": "",
                "captured_at": None,
                "source": SOURCE,
            },
            "geometry": {"type": "Point", "coordinates": coords},
        })
    return {
        "type": "FeatureCollection",
        "name": "Raleigh 50-node template fixture",
        "crs": {"type": "name", "properties": {"name": "EPSG:4326"}},
        "features": normalized,
    }


def configure_inlets(layer: QgsVectorLayer) -> None:
    layer.setReadOnly(False)
    aliases = {
        "node_id": "Inlet label",
        "source_id": "Original Raleigh ID",
        "inlet_uuid": "Stable ID (automatic)",
        "status": "Collection status",
        "notes": "Field notes",
        "captured_at": "Created on device",
        "source": "Data source",
    }
    for name, alias in aliases.items():
        layer.setFieldAlias(layer.fields().indexFromName(name), alias)
    layer.setDefaultValueDefinition(layer.fields().indexFromName("inlet_uuid"), QgsDefaultValue("uuid('WithoutBraces')", False))
    layer.setDefaultValueDefinition(layer.fields().indexFromName("node_id"), QgsDefaultValue("'Field-' || left(uuid('WithoutBraces'), 8)", False))
    layer.setDefaultValueDefinition(layer.fields().indexFromName("captured_at"), QgsDefaultValue("format_date(now(), 'yyyy-MM-ddTHH:mm:ss')", False))
    layer.setDefaultValueDefinition(layer.fields().indexFromName("status"), QgsDefaultValue("'new'", False))
    layer.setDefaultValueDefinition(layer.fields().indexFromName("source"), QgsDefaultValue("'qfield'", False))
    uuid_index = layer.fields().indexFromName("inlet_uuid")
    for constraint in [QgsFieldConstraints.ConstraintNotNull, QgsFieldConstraints.ConstraintUnique]:
        layer.setFieldConstraint(uuid_index, constraint, QgsFieldConstraints.ConstraintStrengthHard)
    for name in ["inlet_uuid", "node_id"]:
        layer.setFieldDuplicatePolicy(layer.fields().indexFromName(name), Qgis.FieldDuplicatePolicy.DefaultValue)
    form = layer.editFormConfig()
    for name in ["fid", "inlet_uuid", "source_id", "source"]:
        index = layer.fields().indexFromName(name)
        if index >= 0:
            form.setReadOnly(index, True)
    layer.setEditFormConfig(form)
    fid_index = layer.fields().indexFromName("fid")
    if fid_index >= 0:
        layer.setEditorWidgetSetup(fid_index, QgsEditorWidgetSetup("Hidden", {}))
    layer.setEditorWidgetSetup(layer.fields().indexFromName("notes"), QgsEditorWidgetSetup("TextEdit", {"IsMultiline": True}))
    layer.setEditorWidgetSetup(layer.fields().indexFromName("status"), QgsEditorWidgetSetup("ValueMap", {"map": [
        {"Sample": "sample"}, {"New": "new"}, {"Surveyed": "surveyed"}, {"Needs review": "needs_review"},
    ]}))
    layer.setDisplayExpression('coalesce(nullif("node_id", \'\'), left("inlet_uuid", 8))')
    layer.setMapTipTemplate('<b>[% "node_id" %]</b><br>[% "status" %]<br>[% "notes" %]')
    layer.renderer().setSymbol(QgsMarkerSymbol.createSimple({
        "name": "circle", "color": "0,80,53,255", "outline_color": "255,255,255,255",
        "outline_width": "0.45", "size": "3.6",
    }))
    text = QgsTextFormat()
    text.setFont(QFont("Noto Sans", 8))
    text.setSize(8)
    text.setColor(QColor("#12372a"))
    buffer = QgsTextBufferSettings()
    buffer.setEnabled(True)
    buffer.setColor(QColor("white"))
    buffer.setSize(0.8)
    text.setBuffer(buffer)
    labeling = QgsPalLayerSettings()
    labeling.fieldName = 'coalesce(nullif("node_id", \'\'), left("inlet_uuid", 8))'
    labeling.isExpression = True
    labeling.setFormat(text)
    layer.setLabeling(QgsVectorLayerSimpleLabeling(labeling))
    layer.setLabelsEnabled(True)


def build(source: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    (output / "data").mkdir(exist_ok=True)
    (output / (Path(PROJECT_FILE).stem + "_attachments.zip")).unlink(missing_ok=True)
    nodes = normalized_nodes(source)
    fixture_path = output / "data/inlets.geojson"
    fixture_path.write_text(json.dumps(nodes, indent=2) + "\n")
    gpkg_path = output / "data/inlets.gpkg"
    gpkg_path.unlink(missing_ok=True)

    project = QgsProject.instance()
    project.clear()
    project.setTitle("DeepPipe Raleigh 50-Node Template")
    project.setFileName(str(output / PROJECT_FILE))
    project.setCrs(QgsCoordinateReferenceSystem("EPSG:3857"))
    project.setFilePathStorage(Qgis.FilePathType.Relative)
    memory = QgsVectorLayer("Point?crs=EPSG:4326", "Inlets", "memory")
    fields = [QgsField(name, QMetaType.Type.QString, len=length) for name, length in [
        ("node_id", 100), ("source_id", 100), ("inlet_uuid", 36),
        ("status", 30), ("notes", 2000), ("captured_at", 40), ("source", 150),
    ]]
    memory.dataProvider().addAttributes(fields)
    memory.updateFields()
    for constraint in [QgsFieldConstraints.ConstraintNotNull, QgsFieldConstraints.ConstraintUnique]:
        memory.setFieldConstraint(memory.fields().indexFromName("inlet_uuid"), constraint, QgsFieldConstraints.ConstraintStrengthHard)
    records = []
    for item in nodes["features"]:
        record = QgsFeature(memory.fields())
        record.setGeometry(QgsGeometry.fromPointXY(QgsPointXY(*item["geometry"]["coordinates"])))
        record.setAttributes([item["properties"][field.name()] for field in fields])
        records.append(record)
    ok, _ = memory.dataProvider().addFeatures(records)
    if not ok:
        raise RuntimeError("Could not prepare sample features.")
    memory.updateExtents()
    options = QgsVectorFileWriter.SaveVectorOptions()
    options.driverName = "GPKG"
    options.layerName = "inlets"
    options.fileEncoding = "UTF-8"
    options.includeConstraints = True
    result = QgsVectorFileWriter.writeAsVectorFormatV3(memory, str(gpkg_path), project.transformContext(), options)
    if result[0] != QgsVectorFileWriter.NoError:
        raise RuntimeError("GeoPackage export failed: " + str(result))
    layer = QgsVectorLayer(str(gpkg_path) + "|layername=inlets", "Inlets", "ogr")
    if not layer.isValid() or layer.featureCount() != 50:
        raise RuntimeError("The exported GeoPackage is invalid.")
    configure_inlets(layer)

    basemap = QgsRasterLayer("type=xyz&url=https://tile.openstreetmap.org/{z}/{x}/{y}.png&zmin=0&zmax=19", "OpenStreetMap (online)", "wms")
    if not basemap.isValid():
        raise RuntimeError("Could not prepare the optional OpenStreetMap XYZ layer.")
    basemap.serverProperties().setAttribution("© OpenStreetMap contributors")
    basemap.serverProperties().setAttributionUrl("https://www.openstreetmap.org/copyright")
    project.addMapLayer(basemap)
    project.addMapLayer(layer)
    extent = QgsCoordinateTransform(layer.crs(), project.crs(), project).transformBoundingBox(layer.extent())
    extent.scale(1.32)
    project.viewSettings().setDefaultViewExtent(QgsReferencedRectangle(extent, project.crs()))
    project.writeEntry("DeepPipe", "enabled", True)
    project.writeEntry("DeepPipe", "schema_version", "1.0")
    project.writeEntry("DeepPipe", "inlet_layer", "Inlets")
    project.writeEntry("DeepPipe", "node_id_field", "inlet_uuid")
    project.writeEntry("DeepPipe", "api_mode", "live")
    metadata = project.metadata()
    metadata.setTitle(project.title())
    metadata.setAuthor("DeepPipe Team")
    metadata.setLanguage("en")
    metadata.setAbstract("Editable GeoPackage copy of the same 50 real Raleigh inlet locations offered by the DeepPipe Portal. No pipe ground truth or connectivity observations are included. OpenStreetMap requires internet access; inlet editing works offline.")
    project.setMetadata(metadata)
    # All symbols and forms are inline. Avoid a generated, unused styles.db
    # attachment so the project has only one portable editable data file.
    project.styleSettings().removeProjectStyle()
    if not project.write():
        raise RuntimeError("Could not write the QGIS project.")
    project.clear()
    # QGIS backups are local editor conveniences, never part of the template.
    (output / (PROJECT_FILE + "~")).unlink(missing_ok=True)
    (output / (Path(PROJECT_FILE).stem + "_attachments.zip")).unlink(missing_ok=True)
    manifest = {
        "template_version": TEMPLATE_VERSION,
        "display_name": "DeepPipe Raleigh 50-Node Template",
        "project_file": PROJECT_FILE,
        "node_count": 50,
        "fixture": "data/inlets.geojson",
        "editable_datasource": "data/inlets.gpkg",
        "node_id_field": "inlet_uuid",
        "display_id_field": "node_id",
        "source_id_field": "source_id",
        "source": SOURCE,
        "source_description": "The same 50 inlet locations in the Portal Raleigh sample, with original IDs preserved as source_id. This is point inventory data, not verified pipe connectivity.",
        "fixture_crs": "EPSG:4326",
        "project_crs": "EPSG:3857",
        "prediction_defaults": {"neighbors_per_sector": 2, "knn_k": 12, "knn_max_distance_ft": 250, "rounds": 3, "use_msf": True},
    }
    (output / "template.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Built {output / PROJECT_FILE} with 50 editable inlets in {gpkg_path}.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=TEMPLATE / "data/inlets.geojson")
    parser.add_argument("--output", type=Path, default=TEMPLATE)
    args = parser.parse_args()
    application = QgsApplication([], False)
    application.initQgis()
    try:
        build(args.source.resolve(), args.output.resolve())
    finally:
        application.exitQgis()


if __name__ == "__main__":
    main()
