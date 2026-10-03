import 'package:winger/domain/medicine_catalog.dart';

/// A small catalogue in the shape of `assets/catalog/medicines.json`, so the
/// domain tests do not depend on the generated asset's exact contents.
const fixtureMedicinesJson = '''
{
  "schema": 1,
  "entries": [
    {"name": "TELMA", "kind": "brand", "source": "curated",
     "salts": ["telmisartan"], "forms": {"tablet": ["20", "40", "80"]}},
    {"name": "TELMA H", "kind": "brand", "source": "curated",
     "salts": ["telmisartan", "hydrochlorothiazide"], "forms": {"tablet": []}},
    {"name": "TELMIKIND", "kind": "brand", "source": "curated",
     "salts": ["telmisartan"], "forms": {"tablet": ["20", "40", "80"]}},
    {"name": "GLYCOMET", "kind": "brand", "source": "curated",
     "salts": ["metformin"], "forms": {"tablet": ["250", "500", "850"]}},
    {"name": "GLYCOMET GP", "kind": "brand", "source": "curated",
     "salts": ["metformin", "glimepiride"],
     "forms": {"tablet": [
       {"label": "1", "dose": {"metformin": "500", "glimepiride": "1"}},
       {"label": "2", "dose": {"metformin": "500", "glimepiride": "2"}}
     ]}},
    {"name": "ECOSPRIN", "kind": "brand", "source": "curated",
     "salts": ["aspirin"], "forms": {"tablet": ["75", "150"]}},
    {"name": "THYRONORM", "kind": "brand", "source": "curated", "unit": "mcg",
     "salts": ["levothyroxine"], "forms": {"tablet": ["25", "50", "100"]}},
    {"name": "AMLOKIND", "kind": "brand", "source": "curated",
     "salts": ["amlodipine"], "forms": {"tablet": ["5", "10"]}},
    {"name": "AMLONG", "kind": "brand", "source": "curated",
     "salts": ["amlodipine"], "forms": {"tablet": ["5", "10"]}},
    {"name": "ROSUVAS", "kind": "brand", "source": "curated",
     "salts": ["rosuvastatin"], "forms": {"tablet": ["10", "20"]}},
    {"name": "STORVAS", "kind": "brand", "source": "curated",
     "salts": ["atorvastatin"], "forms": {"tablet": ["10", "20"]}},
    {"name": "PAN", "kind": "brand", "source": "curated",
     "salts": ["pantoprazole"], "forms": {"tablet": ["20", "40"]}},
    {"name": "DOLO", "kind": "brand", "source": "curated",
     "salts": ["paracetamol"], "forms": {"tablet": ["650"]}},
    {"name": "TELMISARTAN", "kind": "generic", "source": "government",
     "refs": ["janaushadhi"],
     "salts": ["telmisartan"], "forms": {"tablet": ["20", "40", "80"]}},
    {"name": "METFORMIN SR", "kind": "generic", "source": "government",
     "refs": ["janaushadhi"],
     "salts": ["metformin"], "forms": {"tablet": ["500", "1000"]}},
    {"name": "METFORMIN + GLIMEPIRIDE", "kind": "generic",
     "source": "government", "refs": ["janaushadhi"],
     "salts": ["metformin", "glimepiride"],
     "forms": {"tablet": [{"label": "500/1",
       "dose": {"metformin": "500", "glimepiride": "1"}}]}},
    {"name": "PARACETAMOL", "kind": "generic", "source": "government",
     "refs": ["nlem2022"],
     "salts": ["paracetamol"],
     "forms": {"tablet": ["500", "650"], "oral liquid": ["125"]}}
  ]
}
''';

const fixtureLookAlikesJson = '''
{"pairs": [
  {"a": "ROSUVAS", "b": "STORVAS", "why": "Two different statins."}
]}
''';

MedicineCatalog fixtureCatalog() => MedicineCatalog.fromJson(
  fixtureMedicinesJson,
  lookAlikes: fixtureLookAlikesJson,
);
