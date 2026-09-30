import re
from datetime import datetime
from typing import Optional, Tuple

# 37-word domain dictionary from the proven Benchmark MMS system
DICTIONARY_WORDS = [
    'DRIED', 'BUTTERFLY', 'BUTTEFLY', 'BLUE', 'PEA', 'HIBISCUS', 'ROSELLE',
    'CHAMOMILE', 'FLOWER', 'FLOWERS', 'LEAF', 'LEAVES', 'TEA', 'GREEN',
    'BLACK', 'WHITE', 'HERBAL', 'CARDAMOM', 'CLOVE', 'CINNAMON', 'GINGER',
    'PEPPER', 'POWDER', 'EXTRACT', 'OIL', 'ORGANIC', 'WHOLE', 'CRUSHED',
    'FLAVOUR', 'FLAVOR', 'NATURAL', 'TUMBLER', 'SPOON', 'BAG', 'BOX', 'COVER'
]

# Patterns that indicate header/footer/legal boilerplate lines to reject from material descriptions
REJECT_PATTERNS = [
    r"^state\s*name", r"tamil\s*nadu", r"code\s*:\s*\d+", r"gstin", r"uin\b",
    r"consignee", r"ship\s*to", r"buyer", r"bill\s*to", r"invoice\s*no",
    r"motor\s*vehicle", r"terms\s*of\s*delivery", r"reference\s*no", r"e-way",
    r"contact\s*:", r"e-mail", r"bank\s*name", r"kotak", r"declaration",
    r"verified\s*by", r"prepared\s*by", r"customer", r"subject\s*to",
    r"tax\s*invoice", r"e-invoice", r"ack\s*no", r"ack\s*date", r"irn",
    r"description\s*of\s*goods", r"hsn\s*/?\s*sac", r"amount\s*chargeable",
    r"checked\s*by", r"priyanka", r"authoris[a-z]*", r"^total\b", r"subtotal"
]

def split_glued_words(text: str) -> str:
    """Split words that were glued together during OCR scanning using the factory domain dictionary."""
    if not text:
        return ""
    result = text
    for w in sorted(DICTIONARY_WORDS, key=len, reverse=True):
        pattern = re.compile(rf'(?<=[A-Za-z])({w})|({w})(?=[A-Za-z])', re.IGNORECASE)
        result = pattern.sub(r' \1\2 ', result)
    result = re.sub(r'\s+', ' ', result).strip()
    result = re.sub(r'\bBUTTEFLY\b', 'BUTTERFLY', result, flags=re.IGNORECASE)
    return result

def clean_material_name(raw_name: str) -> str:
    """Clean and standardize material descriptions specifically for factory raw & packaging materials.
    Preserves all proven domain corrections from the Benchmark MMS implementation."""
    if not raw_name:
        return ""
    name = str(raw_name).strip()

    # 1. Strip leading serial numbers or stray OCR prefix artifacts ("1 ", "2", "10", "N", "J", etc.)
    name = re.sub(r"^(?:[0-9]{1,2}|[NJAB])[\.\s\)\-]*(?=[A-Za-z])", "", name)

    # 2. Normalize full-width brackets and glue
    name = name.replace("（", "(").replace("）", ")")
    name = split_glued_words(name)

    # 3. Known invoice typo repairs
    name = re.sub(r"\bKosherKing\s*Napkin\b", "Kosher King Napkin", name, flags=re.IGNORECASE)
    name = re.sub(r"\bWOODENSPOONSMALL\b", "WOODEN SPOON SMALL", name, flags=re.IGNORECASE)
    name = re.sub(r"\bWOODENSPOON\b", "WOODEN SPOON ", name, flags=re.IGNORECASE)
    name = re.sub(r"\bPetJar\b", "Pet Jar", name, flags=re.IGNORECASE)
    name = re.sub(r"\bLDCOVER\b", "LD COVER", name, flags=re.IGNORECASE)
    name = re.sub(r"\b4LDCOVER\b", "LD COVER", name, flags=re.IGNORECASE)
    name = re.sub(r"\bST\.POUCH\s*BROWN\b", "ST. POUCH BROWN", name, flags=re.IGNORECASE)
    name = re.sub(r"\bST\.POUCH\b", "ST. POUCH ", name, flags=re.IGNORECASE)
    name = re.sub(r"\bCelloTape\b", "Cello Tape", name, flags=re.IGNORECASE)
    name = re.sub(r"\bCollo\s*Tape\b", "Cello Tape", name, flags=re.IGNORECASE)
    name = re.sub(r"\bCollo\b", "Cello", name, flags=re.IGNORECASE)
    name = re.sub(r"\bPaperstraw\b", "Paper straw", name, flags=re.IGNORECASE)
    name = re.sub(r"\b9Paper\b", "Paper", name, flags=re.IGNORECASE)
    name = re.sub(r"\b10DR\b", "DR", name, flags=re.IGNORECASE)
    name = re.sub(r"\bRippletumb[a-z]*\b", "Ripple tumbler", name, flags=re.IGNORECASE)
    name = re.sub(r"^[rR]own\s*Tape\b", "Brown Tape", name, flags=re.IGNORECASE)
    name = re.sub(r"\bPet\s*Jar\s*-\s*600ML\b", "Pet Jar - 500ML", name, flags=re.IGNORECASE)
    name = re.sub(r"\bPet\s*Jar\s*-\s*500ML\s*\(\s*140\s*\"?", "Pet Jar - 500ML (140)", name, flags=re.IGNORECASE)

    # 4. Strip packaging annotations from the tail (e.g. "- 1 Box", "- 26 Bey", "~IBCX", etc.)
    name = re.sub(r'[-–/]\s*\d*o?\s*(?:Box|Bo|Bk|B0|Bag|Ray|Roll|Pkt|IBCX|Boy|Bey|IBY|1BY|IBA1|Qx|IB|1B|8hewbty).*$', '', name, flags=re.IGNORECASE)
    name = re.sub(r'[-–/]\s*(?:4NO|4\s*No).*$', ' - 4 No', name, flags=re.IGNORECASE)
    name = re.sub(r'[-–/]\s*(?:ROLL|Roll).*$', ' - ROLL', name, flags=re.IGNORECASE)
    name = re.sub(r'[-–/]\s*(?:BoX|Box|IBY|1BY|18|8).*$', '', name, flags=re.IGNORECASE)
    name = re.sub(r'[~|]+.*$', '', name)
    name = re.sub(r'(?<!\d)g$', '"', name)
    name = re.sub(r'3\s*-\s*R$', '3"', name)
    name = re.sub(r'3\s*"\s*-\s*R$', '3"', name)
    name = re.sub(r'Tape3$', 'Tape 3"', name)
    name = re.sub(r'Tape\s*3g$', 'Tape 3"', name)
    name = re.sub(r'1”$', '1" - ROLL', name)

    name = re.sub(r'\((\d+)"', r'(\1)', name)
    name = re.sub(r'\)+', ')', name)

    # 5. Format specs (MM, ML, COVER sizes)
    name = re.sub(r"([a-z])([A-Z])", r"\1 \2", name)
    name = re.sub(r"(\d+ML)", r" \1", name)
    name = re.sub(r"(\d+MM)", r" \1", name)
    name = re.sub(r"\bLDCOVER\b", "LD COVER", name, flags=re.IGNORECASE)
    name = re.sub(r"\b4LDCOVER\b", "LD COVER", name, flags=re.IGNORECASE)
    name = re.sub(r"COVER(\d+)", r"COVER \1", name, flags=re.IGNORECASE)
    name = re.sub(r"COVER\s*6\s*X\s*7", "COVER 5 X 7", name, flags=re.IGNORECASE)
    name = re.sub(r"SMALL-(\d+MM)", r"SMALL - \1", name)
    name = re.sub(r"\bPaper\s*straw\b", "Paper straw - 8MM - WHITE", name, flags=re.IGNORECASE)
    name = re.sub(r"\bDR\s*2[56]0ML\s*Tumbler\b", "DR 250ML Tumbler", name, flags=re.IGNORECASE)
    name = re.sub(r"\bDR2[56]0ML\s*Tumbler\b", "DR 250ML Tumbler", name, flags=re.IGNORECASE)
    name = re.sub(r"\bDR260MLTumbler\b", "DR 250ML Tumbler", name, flags=re.IGNORECASE)

    name = re.sub(r"\s{2,}", " ", name).strip()
    return name.strip(' -/|+')

def normalize_unit(raw_unit: Optional[str]) -> str:
    """Normalize Indian invoice unit strings to canonical units.
    Section 20: Do not change an unfamiliar unit merely because it looks similar."""
    if not raw_unit:
        return "pcs"
    u = raw_unit.strip().lower()
    if u in ('kg', 'kgs', 'kilogram', 'kilograms'):
        return 'kg'
    if u in ('pkt', 'packet', 'packets', 'pke', 'pk'):
        return 'packet'
    if u in ('pcs', 'nos', 'no', 'piece', 'pieces', 'no8'):
        return 'pcs'
    if u in ('roll', 'rolls', 'ro'):
        return 'roll'
    if u in ('box', 'boxes', 'bx'):
        return 'box'
    if u in ('tin', 'tins'):
        return 'tin'
    if u in ('ltr', 'litre', 'litres', 'liter', 'liters', 'l'):
        return 'litre'
    if u in ('g', 'gm', 'gms', 'gram', 'grams'):
        return 'gram'
    if u in ('bag', 'bags'):
        return 'bag'
    # Return as-is if unfamiliar
    return raw_unit.strip()

def clean_amount(val_str: Any, is_quantity: bool = False, is_rate: bool = False) -> float:
    """Extract float amount from formatted string like '84,268.42', '1,779.660', '52.000', or '₹ 98,880.00'.
    Section 19: Distinguish Indian numbers with comma vs decimal properly."""
    if val_str is None:
        return 0.0
    cleaned = str(val_str).replace("₹", "").replace("#", "").replace("Rs.", "").replace("Rs", "").strip()
    if not cleaned:
        return 0.0

    # Handle OCR comma misread as dot for quantities or large whole numbers (e.g. 52.000, 54.600, 3,360)
    # If is_rate is True, 29.661 is clearly twenty-nine rupees point 661, NOT 29661!
    if is_quantity:
        if re.search(r"^\d{1,3}\.\d{3}$", cleaned) and "," not in str(val_str):
            cleaned = cleaned.replace(".", "")
    elif not is_rate:
        # Generic heuristic: 1-3 digits followed by .000 (ending in zeros) is almost always thousands
        if re.search(r"^\d{1,3}\.0{3}$", cleaned):
            cleaned = cleaned.replace(".", "")

    if cleaned.count(".") > 1:
        parts = cleaned.split(".")
        if len(parts[-1]) in [2, 3]:
            cleaned = "".join(parts[:-1]) + "." + parts[-1]
        else:
            cleaned = "".join(parts)

    cleaned = cleaned.replace(",", "")
    match = re.search(r"[-+]?\d+(?:\.\d+)?", cleaned)
    if match:
        try:
            return float(match.group(0))
        except ValueError:
            return 0.0
    return 0.0

def parse_date(raw_str: Optional[str]) -> Tuple[str, bool]:
    """Normalize date strings like '2-Sep-26', '2-8op-26', '28/08/2026', '2026-09-02' to YYYY-MM-DD.
    Section 14: Support 12 formats + OCR month corrections without silent random date injection."""
    if not raw_str:
        return "", False

    cleaned = str(raw_str).strip().replace(",", " ").replace(".", "-").replace("/", "-")
    cleaned = re.sub(r"^(dated|date|on|dt)[:\s\.]*", "", cleaned, flags=re.IGNORECASE).strip()

    # Month OCR corrections (dot-matrix 8op, 8ep, 0ct, etc.)
    cleaned = re.sub(r"\b[8s][eo0]p[t]?\b", "Sep", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\b0ct\b", "Oct", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bdec[a-z]*\b", "Dec", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bjan[a-z]*\b", "Jan", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bfeb[a-z]*\b", "Feb", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bmar[a-z]*\b", "Mar", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bapr[a-z]*\b", "Apr", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bmay\b", "May", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bjun[a-z]*\b", "Jun", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bjul[a-z]*\b", "Jul", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\baug[a-z]*\b", "Aug", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\bnov[a-z]*\b", "Nov", cleaned, flags=re.IGNORECASE)

    m = re.search(r"\b(\d{1,2})[-/\s]([A-Za-z]{3,9}|\d{1,2})[-/\s](\d{2,4})\b", cleaned)
    if m:
        cleaned = f"{m.group(1)}-{m.group(2)}-{m.group(3)}"

    formats = [
        "%d-%b-%y", "%d-%b-%Y", "%d-%B-%y", "%d-%B-%Y",
        "%d-%m-%Y", "%d-%m-%y",
        "%Y-%m-%d", "%Y-%b-%d",
        "%d %b %Y", "%d %b %y", "%d %B %Y", "%d %B %y"
    ]
    for fmt in formats:
        try:
            parsed = datetime.strptime(cleaned, fmt)
            # Basic sanity check on parsed year (e.g. 2000-2035)
            year = parsed.year
            if 2000 <= year <= 2035:
                return parsed.strftime("%Y-%m-%d"), True
        except ValueError:
            continue

    return "", False

GST_REGEX = r"\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}\b"

def validate_gstin(gstin: Optional[str]) -> bool:
    """Section 13: Indian GSTIN structure and validity check."""
    if not gstin:
        return False
    gst = gstin.strip().upper()
    if len(gst) != 15:
        return False
    return bool(re.match(r"^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}$", gst))
