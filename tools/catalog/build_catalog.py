"""Build app/assets/catalog/medicines.json from open government lists.

    python tools/catalog/fetch_sources.py   # once, needs internet
    python tools/catalog/build_catalog.py   # offline, deterministic
    python tools/catalog/build_catalog.py --without-janaushadhi

Inputs (tools/catalog/raw/, see fetch_sources.py):
  janaushadhi_products.json   Jan Aushadhi (PMBJP) product list
  nlem2022_gazette.pdf        National List of Essential Medicines 2022 (Gazette)
  nppa_compendium_2022.pdf    NPPA compendium of ceiling prices, 2022
and tools/catalog/curated_brands.json, the hand-checked brand seed.

Government lists name salts, not brands. Each becomes a *generic* entry:
one per set of salts (and release type, for a single salt), with the dosage
forms and strengths sold. Brands come only from the curated seed, which says
`"source": "curated"` on every entry.

Rules that keep the catalogue honest:
* a strength is recorded only when it is printed next to the medicine, and
  for a combination only when every salt has its own amount;
* liquids, creams and injections keep their form but no strengths (a mg/5 mL
  label is not what a prescription writes after the name);
* nothing is inferred: a product the parser cannot read cleanly is skipped,
  and the count of skipped rows is printed.

Requires PyMuPDF (`pip install pymupdf`).
"""

import collections
import datetime
import json
import pathlib
import re
import sys

import pymupdf

HERE = pathlib.Path(__file__).parent
RAW = HERE / "raw"
OUT = HERE.parent.parent / "app" / "assets" / "catalog" / "medicines.json"

# ── Salt names ──────────────────────────────────────────────────────────────

# Words that name the salt form or the pharmacopoeia, not the medicine.
# Dropped only when trailing, so "sodium valproate" and "calcium carbonate"
# keep their first word.
SALT_FORMS = {
    "hydrochloride", "hcl", "sodium", "potassium", "besilate", "besylate",
    "maleate", "mesylate", "mesilate", "medoxomil", "magnesium", "calcium",
    "fumarate", "succinate", "tartrate", "oxalate", "dihydrate",
    "monohydrate", "trihydrate", "sesquihydrate", "hemihydrate",
    "hydrobromide", "bitartrate", "hyclate", "dipropionate", "propionate",
    "acetate", "valerate", "sulphate", "sulfate", "phosphate", "citrate",
    "etabonate", "anhydrous", "hemifumarate", "disodium", "trisodium",
}

# Spellings in the source lists that mean one salt. Typos are fixed only
# where the list's own other rows spell the same salt correctly.
SYNONYMS = {
    "acetylsalicylic acid": "aspirin",
    "acetylsalicylic acid aspirin": "aspirin",
    "thyroxine": "levothyroxine",
    "levothyroxine": "levothyroxine",
    "frusemide": "furosemide",
    "torasemide": "torsemide",
    "vitamin d3": "cholecalciferol",
    "vitamin c": "ascorbic acid",
    "ascorbic acid vitamin c": "ascorbic acid",
    "potassium clavulanate": "clavulanic acid",
    "clavulanate potassium": "clavulanic acid",
    "clavulanate": "clavulanic acid",
    "diluted potassium clavulanate": "clavulanic acid",
    "glimipride": "glimepiride",
    "chlorthalidon": "chlorthalidone",
    "benedipine": "benidipine",
    "nimesulid": "nimesulide",
    "s amlodipine": "s-amlodipine",
    "s metoprolol": "s-metoprolol",
    "amlodipine besilate": "amlodipine",
    "metoprolol er": "metoprolol",
    "lignocaine": "lidocaine",
    "salbutamol sulphate": "salbutamol",
}

RELEASE = [
    (re.compile(r"sustained[- ]?rel[a-z]*|\(sr\)|\bsr\b", re.I), "SR"),
    (re.compile(r"prolonged[- ]?rel[a-z]*|\bpr\b", re.I), "SR"),
    (re.compile(r"extended[- ]?rel[a-z]*|\ber\b|\bxr\b", re.I), "ER"),
    (re.compile(r"controlled[- ]?rel[a-z]*|\bcr\b", re.I), "CR"),
    (re.compile(r"modified[- ]?rel[a-z]*|\bmr\b", re.I), "MR"),
]

NOISE = re.compile(
    r"\b(ip|bp|usp|i\.p\.?|gastro[- ]?resistant|enteric[- ]?coated|"
    r"film[- ]?coated|uncoated|chewable|dispersible|orally disintegrating|"
    r"mouth dissolving|effervescent|delayed[- ]?release|immediate[- ]?release|"
    r"sustained[- ]?rel[a-z]*|prolonged[- ]?rel[a-z]*|extended[- ]?rel[a-z]*|"
    r"controlled[- ]?rel[a-z]*|modified[- ]?rel[a-z]*|sr|er|xr|pr|cr|mr|ec|"
    r"each|contains?|as|of|equivalent|to|eq|tablets?|capsules?|"
    r"soft gelatin|hard gelatin|w/w|w/v|v/v|per|ml|mg|conventional|soft|"
    r"co-?trimoxazole)\b",
    re.I,
)


def norm_salt(raw):
    """`Metformin Hydrochloride (SR)` → `metformin`. None when unreadable."""
    s = raw.lower()
    s = re.sub(r"\((?:a|b|c|d)\)", " ", s)  # NLEM's (A) + (B) markers
    s = re.sub(r"\([^)]*\)", " ", s)
    s = re.sub(r"[*\[\]]", " ", s)
    s = re.sub(r"\b[pst](?:\s*,\s*[pst])+\b", " ", s)  # NLEM level of care
    s = NOISE.sub(" ", s)
    s = re.sub(r"[^a-z\- ]", " ", s)
    s = NOISE.sub(" ", s)  # again: "per 5ml" only frees "ml" once digits go
    s = re.sub(r"\s+", " ", s).strip(" -")
    s = re.sub(r"^s\s*-\s*", "s-", s)  # S-amlodipine, S(-)amlodipine
    s = SYNONYMS.get(s, s)
    words = s.split()
    while len(words) > 1 and words[-1] in SALT_FORMS:
        words.pop()
    s = " ".join(words)
    s = SYNONYMS.get(s, s)
    if not (3 <= len(s) <= 40) or not re.fullmatch(r"[a-z][a-z\- ]*", s):
        return None
    if s.startswith("water for") or s == "water":
        return None  # sterile water is a diluent, not a medicine to look up
    return s


# ── Dosage forms ────────────────────────────────────────────────────────────

FORMS = [
    (re.compile(r"\b(?:oral )?(?:suspension|syrup|oral liquid|oral solution|"
                r"elixir|dry syrup|oral drops)\b", re.I), "oral liquid"),
    (re.compile(r"\b(?:eye|ear|nasal|eye/ear)[ -]?drops?\b|ophthalmic", re.I),
     "drops"),
    (re.compile(r"\binjections?\b|\binfusion\b|\bvial\b", re.I), "injection"),
    (re.compile(r"\btab(?:let)?s?\b", re.I), "tablet"),
    (re.compile(r"\bcap(?:sule)?s?\b", re.I), "capsule"),
    (re.compile(r"rotacaps?|inhaler|respules?|inhalation|metered dose", re.I),
     "inhalation"),
    (re.compile(r"\b(?:cream|ointment|gel|lotion|dusting powder|soap|"
                r"shampoo|topical)\b", re.I), "topical"),
    (re.compile(r"\bsachets?\b|\bgranules\b|\bpowder\b", re.I), "powder"),
    (re.compile(r"\bspray\b", re.I), "spray"),
    (re.compile(r"\bsuppositor(?:y|ies)\b|\bpessar(?:y|ies)\b", re.I),
     "suppository"),
]
SOLID = {"tablet", "capsule"}


def form_of(text):
    best = None
    for rx, form in FORMS:
        m = rx.search(text)
        if m and (best is None or m.start() < best[0]):
            best = (m.start(), m.end(), form)
    return best


AMOUNT = re.compile(
    r"(\d+(?:\.\d+)?)\s*(mg|mcg|µg|ug|gm|g|iu|i\.u\.)(?![a-z/])", re.I
)


def to_unit(value, unit):
    unit = unit.lower().replace(".", "")
    if unit in ("µg", "ug"):
        unit = "mcg"
    if unit in ("g", "gm"):
        return value * 1000, "mg"
    return value, unit


def fmt(v):
    return str(int(v)) if v == int(v) else f"{v:g}"


# ── The three sources ──────────────────────────────────────────────────────

Product = collections.namedtuple("Product", "salts form release dose ref")
# dose: tuple of (value, unit) per salt, or None when not all are printed.

SKIP_GROUPS = {
    "Surgical & Medical Consumables", "Nutraceuticals", "Ayurvedic",
    "Throat Spray for Freshness",
}


def parse_janaushadhi(rows, skipped):
    out = []
    for p in rows:
        name = p["genericName"]
        if p["groupName"] in SKIP_GROUPS or name.lower().startswith("janaushadhi"):
            continue
        product = parse_line(name, "janaushadhi")
        if product is None:
            skipped["janaushadhi"] += 1
        else:
            out.append(product)
    return out


def parse_line(text, ref):
    """One product line: `Telmisartan 40mg and Amlodipine 5mg Tablets IP`."""
    text = re.sub(r"\((?:as preservative|[^)]*base)\)", " ", text, flags=re.I)
    text = re.sub(r"soft\s*gel(?:atin)?(?:\s*capsules?)?", " capsule ", text, flags=re.I)
    found = form_of(text)
    if found is None:
        return None
    start, end, form = found
    head, tail = text[:start], text[end:]
    if not head.strip():
        return None
    release = None
    for rx, label in RELEASE:
        if rx.search(text):
            release = label
            break

    chunks = [
        c for c in re.split(r"\s*(?:\+|,|&|\band\b|\bwith\b)\s*", head, flags=re.I)
        if c.strip()
    ]
    salts, inline = [], []
    for c in chunks:
        amounts = AMOUNT.findall(c)
        salt = norm_salt(AMOUNT.sub(" ", c))
        if salt is None:
            continue
        salts.append(salt)
        inline.append(to_unit(float(amounts[0][0]), amounts[0][1]) if amounts else None)
    if not salts or len(set(salts)) != len(salts):
        return None

    dose = None
    if all(inline):
        dose = tuple(inline)
    else:
        # "Tablet (40/5 Mg)", "Tablets IP 500mg/2mg", "Tablets IP 40mg".
        slash = re.search(
            r"\(?\s*(\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)*)\s*(mg|mcg|iu)\b",
            tail, re.I,
        )
        if slash:
            values = [float(v) for v in re.split(r"\s*/\s*", slash.group(1))]
            if len(values) == len(salts):
                dose = tuple(to_unit(v, slash.group(2)) for v in values)
        else:
            amounts = AMOUNT.findall(tail)
            if len(amounts) == len(salts):
                dose = tuple(to_unit(float(v), u) for v, u in amounts)
    if form not in SOLID:
        dose = None
    return Product(tuple(salts), form, release if len(salts) == 1 else None, dose, ref)


SECTION = re.compile(r"^\d{1,2}(?:\.\d{1,2}){1,3}$")
LEVEL = re.compile(r"^[PST](?:\s*,\s*[PST])*$")
DOSAGE_START = re.compile(
    r"^(?:Tablet|Capsule|Injection|Oral|Powder|Syrup|Suspension|Drops|Eye|Ear|"
    r"Nasal|Cream|Ointment|Gel|Lotion|Inhalation|Respirator|Spray|Suppository|"
    r"Lozenge|Sachet|Solution|Effervescent|Dispersible|Enteric|Chewable|"
    r"Sustained|Prolonged|Modified|Controlled|Extended|Topical|Dry|MDI|DPI|"
    r"Vaginal|Pessary|Transdermal|Liquid|Granules|Film|Mouth)",
    re.I,
)
HEADER_WORDS = {
    "medicine", "level of", "healthcare", "dosage form(s) and strength(s)",
    "healthcare dosage form(s) and strength(s)", "section of", "nlem",
    "medicines", "ceiling price", "(rs.)", "s.o. no.", "date of notification",
    "dosage form and strength     unit/pack size", "dosage form and strength unit/pack size",
}


def pdf_lines(path, pages):
    doc = pymupdf.open(path)
    for i in pages(doc.page_count):
        for line in doc[i].get_text().splitlines():
            line = line.strip()
            if line:
                yield line


def parse_listing(path, ref, pages, skipped):
    """NLEM and the NPPA compendium share a shape: a section number, the
    medicine's name over one or more lines, then one line per dosage form
    and strength. Everything else on the page is skipped."""
    out = []
    name, state, pending = [], "idle", ""
    lines = list(pdf_lines(path, pages))
    for i, line in enumerate(lines):
        low = line.lower()
        following = lines[i + 1] if i + 1 < len(lines) else ""
        # A section number is followed by a name. A price ("1.34") looks the
        # same, and is followed by its notification number ("1499(E)").
        if SECTION.match(line) and re.match(r"[A-Za-z]", following)                 and not DOSAGE_START.match(following):
            name, state, pending = [], "name", ""
            continue
        if low in HEADER_WORDS or re.fullmatch(r"\(\d\)", line) or line.startswith("*") \
                or "listed in" in low or low.startswith("section "):
            continue
        if state == "name":
            if LEVEL.match(line):
                continue
            if DOSAGE_START.match(line):
                state = "dosage"
            else:
                name.append(line.replace("*", "").strip())
                continue
        if state != "dosage":
            continue
        if not DOSAGE_START.match(line) and not pending:
            continue
        text = f"{pending} {line}".strip()
        if not re.search(r"\d", text) and DOSAGE_START.match(line):
            pending = text  # "Effervescent/ Dispersible/" wraps onto the next line
            continue
        pending = ""
        product = parse_dosage(" ".join(name), text, ref)
        if product is None:
            skipped[ref] += 1
        else:
            out.append(product)
    return out


def parse_dosage(medicine, line, ref):
    """`Amoxicillin (A) + Clavulanic acid (B)`, `Tablet 500 mg (A) + 125 mg (B)`."""
    parts = [p for p in re.split(r"\s*\+\s*", medicine) if p.strip()]
    salts = [norm_salt(p) for p in parts]
    if not salts or None in salts or len(set(salts)) != len(salts):
        return None
    found = form_of(line)
    if found is None:
        return None
    form = found[2]
    release = None
    for rx, label in RELEASE:
        if rx.search(line):
            release = label
            break
    amounts = AMOUNT.findall(line)
    dose = None
    if form in SOLID and len(amounts) == len(salts) and "/" not in line:
        dose = tuple(to_unit(float(v), u) for v, u in amounts)
    return Product(tuple(salts), form, release if len(salts) == 1 else None, dose, ref)


# ── Merge into entries ─────────────────────────────────────────────────────


def canonical_salts(products):
    """One spelling per salt. The lists write `benzylpenicillin` and `benzyl
    penicillin`, `levothyroxine` and `levo-thyroxine`; the app looks names up
    by their letters, so both must be one entry. The most used spelling wins,
    then the one with the fewest spaces and hyphens."""
    seen = collections.defaultdict(collections.Counter)
    for p in products:
        for s in p.salts:
            seen[re.sub(r"[^a-z]", "", s)][s] += 1
    pick = {
        k: max(c, key=lambda s: (c[s], -len(re.findall(r"[^a-z]", s))))
        for k, c in seen.items()
    }
    out = []
    for p in products:
        salts = tuple(pick[re.sub(r"[^a-z]", "", s)] for s in p.salts)
        if len(set(salts)) == len(salts):
            out.append(p._replace(salts=salts))
    return out


def build(products, curated):
    products = canonical_salts(products)
    by_key = {}
    unit_votes = collections.defaultdict(collections.Counter)
    for p in products:
        if p.dose and len(p.salts) == 1:
            unit_votes[p.salts[0]][p.dose[0][1]] += 1
    salt_unit = {s: c.most_common(1)[0][0] for s, c in unit_votes.items()}

    for p in products:
        key = (tuple(sorted(p.salts)), p.release)
        e = by_key.get(key)
        if e is None:
            name = " + ".join(s.upper() for s in p.salts)
            if p.release:
                name += f" {p.release}"
            e = by_key[key] = {
                "name": name,
                "kind": "generic",
                "source": "government",
                "refs": set(),
                "salts": list(p.salts),
                "forms": collections.defaultdict(dict),
            }
        e["refs"].add(p.ref)
        strengths = e["forms"][p.form]
        if not p.dose:
            continue
        # Amounts in the order of this entry's salts, in each salt's usual unit.
        order = {s: i for i, s in enumerate(p.salts)}
        values = []
        for s in e["salts"]:
            v, u = p.dose[order[s]]
            want = salt_unit.get(s, u)
            if u != want:
                if (u, want) == ("mg", "mcg"):
                    v *= 1000
                elif (u, want) == ("mcg", "mg"):
                    v /= 1000
                else:
                    break
            values.append(v)
        else:
            label = "/".join(fmt(v) for v in values)
            if len(values) == 1:
                strengths[label] = label
            else:
                strengths[label] = {
                    "label": label,
                    "dose": {s: fmt(v) for s, v in zip(e["salts"], values)},
                }

    generics = []
    for e in by_key.values():
        forms = {}
        for form, labels in sorted(e["forms"].items()):
            items = sorted(
                labels.values(),
                key=lambda x: [float(n) for n in (x if isinstance(x, str) else x["label"]).split("/")],
            )
            forms[form] = items
        entry = {
            "name": e["name"],
            "kind": "generic",
            "source": "government",
            "refs": sorted(e["refs"]),
            "salts": e["salts"],
            "forms": forms,
        }
        if len(e["salts"]) == 1 and salt_unit.get(e["salts"][0], "mg") != "mg":
            entry["unit"] = salt_unit[e["salts"][0]]
        generics.append(entry)
    generics.sort(key=lambda x: x["name"])

    known_salts = {s for g in generics for s in g["salts"]}
    brands = []
    for b in curated["brands"]:
        missing = [s for s in b["salts"] if s not in known_salts]
        if missing:
            print(f"  note: {b['name']} salt(s) not in government lists: {missing}")
        entry = {
            "name": b["name"],
            "kind": "brand",
            "source": "curated",
            "salts": b["salts"],
            "forms": {b["form"]: b.get("strengths", [])},
        }
        if "unit" in b:
            entry["unit"] = b["unit"]
        brands.append(entry)
    names = [e["name"] for e in brands + generics]
    dupes = [n for n, c in collections.Counter(names).items() if c > 1]
    if dupes:
        sys.exit(f"duplicate names: {dupes}")
    return brands, generics


def main():
    skipped = collections.Counter()
    if "--without-janaushadhi" in sys.argv:
        # Jan Aushadhi's portal asks for permission by email before its
        # material is reproduced (SOURCES.md). This builds without it.
        products = []
    else:
        ja = json.loads((RAW / "janaushadhi_products.json").read_text(encoding="utf-8"))
        products = parse_janaushadhi(ja, skipped)
    print(f"janaushadhi: {len(products)} products read, {skipped['janaushadhi']} skipped")

    # NLEM 2022 as Schedule-I in the Gazette: Hindi first, then English from
    # page 59 to the end. The parser only reads the English half.
    nlem = parse_listing(
        RAW / "nlem2022_gazette.pdf", "nlem2022", lambda n: range(58, n), skipped
    )
    print(f"nlem2022: {len(nlem)} formulations read, {skipped['nlem2022']} skipped")
    nppa = parse_listing(
        RAW / "nppa_compendium_2022.pdf", "nppa2022", lambda n: range(2, n), skipped
    )
    print(f"nppa2022: {len(nppa)} formulations read, {skipped['nppa2022']} skipped")

    curated = json.loads((HERE / "curated_brands.json").read_text(encoding="utf-8"))
    brands, generics = build(products + nlem + nppa, curated)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [json.dumps(e, ensure_ascii=False, separators=(",", ":")) for e in brands + generics]
    header = {
        "schema": 1,
        # The day the sources were fetched, so a rebuild is byte-identical.
        "generated": datetime.date.fromtimestamp(
            (RAW / "janaushadhi_products.json").stat().st_mtime
        ).isoformat(),
        "counts": {"brands": len(brands), "generics": len(generics)},
        "sources": "see SOURCES.md",
    }
    body = ",\n".join(lines)
    head = json.dumps(header, ensure_ascii=False)[:-1]
    OUT.write_text(f'{head},\n"entries":[\n{body}\n]}}\n', encoding="utf-8")
    size = OUT.stat().st_size
    print(f"wrote {OUT.relative_to(HERE.parent.parent)}: {len(brands)} brands, "
          f"{len(generics)} generics, {size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
