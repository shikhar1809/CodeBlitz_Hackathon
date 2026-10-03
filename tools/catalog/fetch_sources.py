"""Download the open Indian government medicine lists the catalogue is built from.

    python tools/catalog/fetch_sources.py

Writes into tools/catalog/raw/ (not committed) and prints a SHA-256 for each
file, to copy into app/assets/catalog/SOURCES.md.

Only government publications are fetched:

* Jan Aushadhi (PMBJP / PMBI) product list - the same public JSON the
  janaushadhi.gov.in "Product Portfolio" page reads. The site's own
  anonymous guest token is requested first, exactly as the browser does.
* National List of Essential Medicines 2022 - the Gazette notification
  (S.O. 5249(E)) as published by NPPA.
* NPPA Compendium of Ceiling Prices 2022 - PDF published by NPPA.

No commercial or scraped dataset (1mg, Kaggle scrapes, ...) is ever used.
"""

import hashlib
import json
import pathlib
import sys
import urllib.request

RAW = pathlib.Path(__file__).parent / "raw"

JA_TOKEN = "https://janaushadhi.gov.in:8443/auth/generateGuestToken"
JA_PRODUCTS = "https://janaushadhi.gov.in:8443/api/v1/website/getAllProductForWeb"
# NLEM 2022 as notified in the Gazette of India (S.O. 5249(E), 11 Nov 2022,
# Schedule-I of the DPCO 2013), from NPPA. NPPA's copyright policy allows
# reproduction with acknowledgement; CDSCO's own copy of the list does not.
NLEM_2022 = (
    "https://nppa.gov.in/storage/uploads/pdf/"
    "nlem-2022pdf-0cd1d2b28855bf30128875ab19fc5304.pdf"
)
NPPA_2022 = (
    "https://nppa.gov.in/storage/uploads/pdf/"
    "Compendium-Prices-2022pdf-464b22085495ff4e3f8700c0e00cf45d.pdf"
)

UA = {"User-Agent": "Winger catalogue builder (open data; see SOURCES.md)"}


def _get(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers={**UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def fetch_janaushadhi():
    token = json.loads(_get(JA_TOKEN))["responseBody"]
    body = json.dumps(
        {
            "pageIndex": 0,
            "pageSize": 5000,
            "searchText": "",
            "columnName": "id",
            "orderBy": "asc",
        }
    ).encode()
    raw = _get(
        JA_PRODUCTS,
        data=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    data = json.loads(raw)["responseBody"]
    products = data["newProductResponsesList"]
    if len(products) != data["totalElement"]:
        sys.exit(f"Jan Aushadhi: got {len(products)} of {data['totalElement']}")
    return json.dumps(products, ensure_ascii=False, indent=1).encode()


def main():
    RAW.mkdir(exist_ok=True)
    jobs = [
        ("janaushadhi_products.json", fetch_janaushadhi),
        ("nlem2022_gazette.pdf", lambda: _get(NLEM_2022)),
        ("nppa_compendium_2022.pdf", lambda: _get(NPPA_2022)),
    ]
    for name, fetch in jobs:
        blob = fetch()
        (RAW / name).write_bytes(blob)
        digest = hashlib.sha256(blob).hexdigest()
        print(f"{name}  {len(blob):>9} bytes  sha256 {digest}")


if __name__ == "__main__":
    main()
