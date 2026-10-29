#!/usr/bin/env python3
"""Native PyQGIS tests for the editable Raleigh 50-node project.

Run with the Python environment supplied by QGIS 3.40+. Every edit is performed
on an isolated temporary copy, never on the distributed template. Set
DEEPPIPE_PORTAL_SAMPLE to the Portal's original sample for an extra cross-check.
"""

from __future__ import annotations

import json
from contextlib import closing
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile
import unittest
import uuid
import xml.etree.ElementTree as ET

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from qgis.core import (
    Qgis,
    QgsApplication,
    QgsFieldConstraints,
    QgsGeometry,
    QgsPointXY,
    QgsProject,
    QgsVectorDataProvider,
    QgsVectorLayerUtils,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "project-template"


class EditableTemplateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QgsApplication([], False)
        cls.app.initQgis()
        cls.manifest = json.loads((SOURCE / "template.json").read_text())
        cls.fixture = json.loads((SOURCE / cls.manifest["fixture"]).read_text())

    @classmethod
    def tearDownClass(cls):
        QgsProject.instance().clear()
        cls.app.exitQgis()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="deeppipe-template-test-")
        self.folder = Path(self.temp.name) / "project"
        shutil.copytree(SOURCE, self.folder)
        self.project = QgsProject.instance()
        self.project.clear()
        self.project_path = self.folder / self.manifest["project_file"]
        self.assertTrue(self.project.read(str(self.project_path)))
        self.layer = self.project.mapLayersByName("Inlets")[0]
        self.assertTrue(self.layer.isValid())

    def tearDown(self):
        self.layer = None
        self.project.clear()
        self.temp.cleanup()

    def reload(self):
        self.layer = None
        self.project.clear()
        self.assertTrue(self.project.read(str(self.project_path)))
        self.layer = self.project.mapLayersByName("Inlets")[0]
        self.assertTrue(self.layer.isValid())

    def test_sample_matches_exact_50_fixture_locations_and_source_ids(self):
        self.assertEqual(self.layer.featureCount(), 50)
        expected = {str(f["properties"]["source_id"]): f for f in self.fixture["features"]}
        self.assertEqual(len(expected), 50)
        actual_ids = set()
        for feature in self.layer.getFeatures():
            source_id = str(feature["source_id"])
            actual_ids.add(source_id)
            self.assertEqual(str(feature["node_id"]), source_id)
            fixture = expected[source_id]
            self.assertEqual(str(feature["inlet_uuid"]), fixture["properties"]["inlet_uuid"])
            point = feature.geometry().asPoint()
            self.assertAlmostEqual(point.x(), fixture["geometry"]["coordinates"][0], places=12)
            self.assertAlmostEqual(point.y(), fixture["geometry"]["coordinates"][1], places=12)
        self.assertEqual(actual_ids, set(expected))
        self.assertEqual(self.layer.crs().authid(), "EPSG:4326")
        self.assertEqual(self.project.crs().authid(), "EPSG:3857")

    def test_optional_original_portal_fixture_matches(self):
        path = os.environ.get("DEEPPIPE_PORTAL_SAMPLE")
        if not path:
            self.skipTest("Set DEEPPIPE_PORTAL_SAMPLE for the cross-repository Portal comparison.")
        portal = json.loads(Path(path).read_text())
        original = {str(f["properties"]["ID"]): f["geometry"]["coordinates"] for f in portal["features"]}
        current = {str(f["source_id"]): [f.geometry().asPoint().x(), f.geometry().asPoint().y()] for f in self.layer.getFeatures()}
        self.assertEqual(len(original), 50)
        self.assertEqual(current, original)

    def test_project_is_portable_and_premapped_for_plugin(self):
        source = Path(self.layer.source().split("|", 1)[0]).resolve()
        self.assertEqual(source, (self.folder / "data/inlets.gpkg").resolve())
        self.assertEqual(self.project.readEntry("DeepPipe", "inlet_layer", "")[0], "Inlets")
        self.assertEqual(self.project.readEntry("DeepPipe", "node_id_field", "")[0], "inlet_uuid")
        self.assertEqual(self.project.readEntry("DeepPipe", "api_mode", "")[0], "live")
        self.assertEqual(self.project.filePathStorage(), Qgis.FilePathType.Relative)
        document = ET.parse(self.project_path)
        sources = [node.text for node in document.findall("./projectlayers/maplayer/datasource")]
        self.assertIn("./data/inlets.gpkg|layername=inlets", sources)
        self.assertTrue(all("/workspace/" not in str(value) and "/tank/" not in str(value) for value in sources))
        self.assertFalse(any(".geojson" in str(value) for value in sources), "Fixture must not be a second editable source")

    def test_editing_capabilities_and_uuid_form_defaults(self):
        self.assertFalse(self.layer.readOnly())
        capabilities = self.layer.dataProvider().capabilities()
        for required in [QgsVectorDataProvider.AddFeatures, QgsVectorDataProvider.DeleteFeatures,
                         QgsVectorDataProvider.ChangeGeometries, QgsVectorDataProvider.ChangeAttributeValues]:
            self.assertTrue(capabilities & required)
        index = self.layer.fields().indexFromName("inlet_uuid")
        default = self.layer.defaultValueDefinition(index)
        self.assertEqual(default.expression(), "uuid('WithoutBraces')")
        self.assertFalse(default.applyOnUpdate())
        self.assertTrue(self.layer.editFormConfig().readOnly(index))
        self.assertEqual(self.layer.fields().at(index).duplicatePolicy(), Qgis.FieldDuplicatePolicy.DefaultValue)
        constraints = self.layer.fields().at(index).constraints()
        for constraint in [QgsFieldConstraints.ConstraintUnique, QgsFieldConstraints.ConstraintNotNull]:
            self.assertTrue(constraints.constraints() & constraint)
            self.assertEqual(constraints.constraintStrength(constraint), QgsFieldConstraints.ConstraintStrengthHard)
        uuids = [str(feature["inlet_uuid"]) for feature in self.layer.getFeatures()]
        self.assertEqual(len(set(uuids)), 50)
        self.assertTrue(all(str(uuid.UUID(value)) == value for value in uuids))

    def test_add_two_points_uses_unique_defaults_and_survives_save_reopen(self):
        self.assertTrue(self.layer.startEditing())
        created = []
        for longitude in [-78.6544, -78.6545]:
            geometry = QgsGeometry.fromPointXY(QgsPointXY(longitude, 35.811))
            feature = QgsVectorLayerUtils.createFeature(self.layer, geometry, {}, self.layer.createExpressionContext())
            identifier = str(feature["inlet_uuid"])
            self.assertEqual(str(uuid.UUID(identifier)), identifier)
            self.assertTrue(str(feature["node_id"]).startswith("Field-"))
            self.assertEqual(feature["status"], "new")
            self.assertEqual(feature["source"], "qfield")
            self.assertTrue(str(feature["captured_at"]))
            self.assertTrue(self.layer.addFeature(feature))
            created.append(identifier)
        self.assertNotEqual(*created)
        self.assertTrue(self.layer.commitChanges(), self.layer.commitErrors())
        self.assertTrue(self.project.write())
        self.reload()
        self.assertEqual(self.layer.featureCount(), 52)
        identifiers = {str(feature["inlet_uuid"]) for feature in self.layer.getFeatures()}
        self.assertTrue(set(created).issubset(identifiers))

    def test_edit_geometry_and_attributes_keeps_stable_identity(self):
        before = next(self.layer.getFeatures())
        identifier = str(before["inlet_uuid"])
        source_id = str(before["source_id"])
        point = before.geometry().asPoint()
        longitude, latitude = point.x() + 0.00002, point.y() + 0.00003
        self.assertTrue(self.layer.startEditing())
        self.assertTrue(self.layer.changeGeometry(before.id(), QgsGeometry.fromPointXY(QgsPointXY(longitude, latitude))))
        self.assertTrue(self.layer.changeAttributeValue(before.id(), self.layer.fields().indexFromName("notes"), "Field verification note"))
        self.assertTrue(self.layer.changeAttributeValue(before.id(), self.layer.fields().indexFromName("node_id"), "Field label changed"))
        self.assertTrue(self.layer.commitChanges(), self.layer.commitErrors())
        self.assertTrue(self.project.write())
        self.reload()
        after = next(feature for feature in self.layer.getFeatures() if str(feature["inlet_uuid"]) == identifier)
        self.assertEqual(str(after["source_id"]), source_id)
        self.assertEqual(str(after["notes"]), "Field verification note")
        self.assertEqual(str(after["node_id"]), "Field label changed")
        self.assertAlmostEqual(after.geometry().asPoint().x(), longitude, places=12)
        self.assertAlmostEqual(after.geometry().asPoint().y(), latitude, places=12)

    def test_delete_point_survives_reopen_without_changing_other_ids(self):
        original = {str(feature["inlet_uuid"]) for feature in self.layer.getFeatures()}
        feature = next(self.layer.getFeatures())
        removed = str(feature["inlet_uuid"])
        self.assertTrue(self.layer.startEditing())
        self.assertTrue(self.layer.deleteFeature(feature.id()))
        self.assertTrue(self.layer.commitChanges(), self.layer.commitErrors())
        self.reload()
        self.assertEqual(self.layer.featureCount(), 49)
        current = {str(feature["inlet_uuid"]) for feature in self.layer.getFeatures()}
        self.assertEqual(current, original - {removed})

    def test_geopackage_is_valid_sqlite_and_has_no_pending_journal(self):
        path = self.folder / "data/inlets.gpkg"
        with closing(sqlite3.connect(path)) as connection:
            self.assertEqual(connection.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            self.assertEqual(connection.execute("SELECT count(*) FROM inlets").fetchone()[0], 50)
            uuid_field = next(row for row in connection.execute("PRAGMA table_info(inlets)") if row[1] == "inlet_uuid")
            self.assertEqual(uuid_field[3], 1, "UUID is NOT NULL in the actual GeoPackage schema")
        self.assertFalse(Path(str(SOURCE / "data/inlets.gpkg") + "-wal").exists())
        self.assertFalse(Path(str(SOURCE / "data/inlets.gpkg") + "-shm").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
