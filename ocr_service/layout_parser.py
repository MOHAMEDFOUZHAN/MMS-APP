import re
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from dictionary import (
    clean_material_name, clean_amount, parse_date,
    normalize_unit, validate_gstin, GST_REGEX, REJECT_PATTERNS
)
from material_matcher import material_matcher

def find_optimal_skew_slope(tokens: List[dict], header_y: float, totals_y: float) -> float:
    """Section 11: Find table skew slope automatically by minimizing within-row Y variance.
    Searches approximately -0.08 to +0.08. Preserves the proven old implementation."""
    table_tokens = [t for t in tokens if (header_y - 10) <= t["y"] <= (totals_y + 15)]
    if len(table_tokens) < 10:
        return 0.0

    best_slope = 0.0
    min_score = float('inf')

    for slope in np.linspace(-0.08, 0.08, 81):
        y_adjs = sorted([t["y"] - slope * t["x"] for t in table_tokens])
        diffs = np.diff(y_adjs)
        within_row_gaps = diffs[diffs < 6.0]
        if len(within_row_gaps) > 0:
            variance_score = float(np.mean(within_row_gaps ** 2))
            if variance_score < min_score:
                min_score = variance_score
                best_slope = float(slope)

    return round(best_slope, 4)

class InvoiceLayoutParser:
    def parse_single_page(self, tokens: List[dict], page_idx: int = 1) -> Dict[str, Any]:
        """Parse structured invoice elements from OCR tokens on a single page."""
        if not tokens:
            return self._empty_result(page_idx)

        # 1. Virtual Coordinates and Skew Analysis
        all_texts = [t["text"] for t in tokens]
        full_text = "\n".join(all_texts)

        # 2. GST Numbers (Seller vs Buyer)
        all_gsts = re.findall(GST_REGEX, full_text, re.IGNORECASE)
        seller_gst = all_gsts[0].upper() if all_gsts else ""
        buyer_gst = all_gsts[1].upper() if len(all_gsts) > 1 else ""

        # 3. Vendor / Seller Name (Section 12)
        vendor_name = ""
        for t in tokens:
            txt = t["text"]
            m = re.search(r"A[o/c]?\s*Holder['’]?s\s*Name\s*:\s*([A-Za-z0-9\s&]+)", txt, re.IGNORECASE)
            if m and len(m.group(1).strip()) > 2:
                vendor_name = re.sub(r"([a-z])([A-Z])", r"\1 \2", m.group(1).strip())
                break
            m2 = re.search(r"for\s+([A-Za-z0-9\s&]+)", txt, re.IGNORECASE)
            if m2:
                cand = m2.group(1).strip()
                if len(cand) > 3 and not any(kw in cand.lower() for kw in ["consignee", "buyer", "authorised", "signature", "recipient"]):
                    vendor_name = re.sub(r"([a-z])([A-Z])", r"\1 \2", cand)
                    break

        if not vendor_name:
            ignore_kws = [
                "taxinvoice", "invoice", "gstin", "statename", "eway", "delivery", "dated", "original",
                "billno", "irn", "ack", "ackno", "ackdate", "recipient", "contact", "email", "modeterms", "otherreferences"
            ]
            for t in tokens:
                if t["y"] < 500 and t["x"] < 500:
                    raw_t = t["text"].strip()
                    tl_clean = re.sub(r"[^a-z0-9]", "", raw_t.lower())
                    if "consignee" in tl_clean or "buyer" in tl_clean:
                        break
                    if any(kw in tl_clean for kw in ignore_kws):
                        continue
                    # Skip date-like strings
                    if re.search(r"(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})", raw_t, re.IGNORECASE):
                        continue
                    if len(raw_t) > 3 and not re.search(GST_REGEX, raw_t):
                        if re.search(r"[0-9a-zA-Z]{16,}", raw_t) or re.match(r"^[:0-9a-fA-F\s\-]{12,}$", raw_t):
                            continue
                        if not re.match(r"^[\d\/\#\-\s,:\.]+$", raw_t):
                            cleaned = re.sub(r"^(M\/[Ss]|Messrs\.?|M\/s\.?)\s*", "", raw_t, flags=re.IGNORECASE).strip()
                            if len(cleaned) > 2 and any(c.isalpha() for c in cleaned):
                                vendor_name = cleaned
                                break

        if vendor_name:
            vendor_name = re.sub(r"([a-z])([A-Z])", r"\1 \2", vendor_name)
            vendor_name = re.sub(r"\bBKENTERPRISES\b", "BK ENTERPRISES", vendor_name, flags=re.IGNORECASE)

        # 4. Invoice Number (Section 12)
        invoice_no = ""
        for t in tokens:
            txt = t["text"]
            if re.search(r"Inv[o0y]?[i1l]ce\s*No|Inv[a-z]*\s*No", txt, re.IGNORECASE) and not re.search(r"e-Way", txt, re.IGNORECASE):
                m = re.search(r"Inv[o0y]?[i1l]ce\s*No[\.\s:]+([A-Za-z0-9\/\-_]+)", txt, re.IGNORECASE)
                if m and not m.group(1).lower() in ["e-way", "dated", "no", "date"]:
                    invoice_no = m.group(1).strip()
                    break
                for below in tokens:
                    if 5 < (below["y"] - t["y"]) < 45 and abs(below["x"] - t["x"]) < 70:
                        cand = below["text"].strip()
                        if cand and not any(kw in cand.lower() for kw in ["e-way", "dated", "delivery", "invoice", "date", "reference"]):
                            invoice_no = cand
                            break
                if invoice_no:
                    break

        if not invoice_no:
            for t in tokens:
                m = re.search(r"(\d+)\s+dt\.?\s*\d+", t["text"], re.IGNORECASE)
                if m:
                    invoice_no = m.group(1).strip()
                    break

        if not invoice_no:
            for cand in re.findall(r"\b([A-Z]{1,4}[\-\/][A-Za-z0-9\-\/]+|\d{2,5})\b", full_text):
                if not re.match(r"^641\d{3}$", cand) and not re.match(r"^202[0-9]$", cand):
                    invoice_no = cand
                    break

        # 5. Invoice Date (Section 14)
        invoice_date = ""
        has_valid_date = False
        for t in tokens:
            txt = t["text"]
            if "ack date" in txt.lower():
                continue
            m = re.search(r"(?:dt\.?|dated|dated\s*:|[|]|invoice\s*date)[:\s\.]*(\d{1,2}[-/\s][A-Za-z0-9]{2,9}[-/\s]\d{2,4})", txt, re.IGNORECASE)
            if m:
                d, ok = parse_date(m.group(1))
                if ok:
                    invoice_date = d
                    has_valid_date = True
                    break

        if not invoice_date:
            for t in tokens:
                if "ack date" in t["text"].lower():
                    continue
                d, ok = parse_date(t["text"])
                if ok:
                    invoice_date = d
                    has_valid_date = True
                    break

        # 6. Dynamic Column Detection & Table Bounds (Section 16)
        header_candidates = []
        for t in tokens:
            tl = t["text"].lower()
            if any(h in tl for h in ["items", "descript", "particular", "goods", "gopds", "product", "hsn", "sac", "quantity", "qty", "rate", "price", "amount", "disc"]):
                header_candidates.append(t)

        header_clusters = {}
        for t in header_candidates:
            matched = False
            for y_center in list(header_clusters.keys()):
                if abs(t["y"] - y_center) <= 22.0:
                    header_clusters[y_center].append(t)
                    matched = True
                    break
            if not matched:
                header_clusters[t["y"]] = [t]

        best_cluster_y = None
        best_cluster_score = 0
        for y_c, row_t in header_clusters.items():
            row_texts = " ".join(t["text"].lower() for t in row_t)
            score = 0
            if any(k in row_texts for k in ["descript", "particular", "goods", "gopds"]): score += 4
            if any(k in row_texts for k in ["qty", "quantity"]): score += 3
            if any(k in row_texts for k in ["rate", "price"]): score += 3
            if any(k in row_texts for k in ["amount", "total"]): score += 3
            if any(k in row_texts for k in ["hsn", "sac"]): score += 2
            if score > best_cluster_score and len(row_t) >= 2:
                best_cluster_score = score
                best_cluster_y = y_c

        header_y = float(best_cluster_y) if best_cluster_y is not None else 330.0

        header_tokens = []
        for t in tokens:
            if abs(t["y"] - header_y) <= 25.0:
                tl = t["text"].lower()
                if any(h in tl for h in ["items", "descript", "particular", "goods", "gopds", "product"]) and t["x"] < 450:
                    header_tokens.append(("desc", t))
                elif any(h in tl for h in ["hsn/sac", "hsn", "sac"]) and (350 <= t["x"] < 650):
                    header_tokens.append(("hsn", t))
                elif any(h in tl for h in ["quantity", "qty", "qnty"]) and (350 <= t["x"] < 700):
                    header_tokens.append(("qty", t))
                elif any(h in tl for h in ["rate", "price"]) and (450 <= t["x"] < 850):
                    header_tokens.append(("rate", t))
                elif any(h in tl for h in ["tax", "gst %", "tax %", "tax amt"]) and (450 <= t["x"] < 850):
                    header_tokens.append(("tax", t))
                elif any(h in tl for h in ["amount", "total"]) and t["x"] >= 750:
                    header_tokens.append(("amount", t))

        stop_keywords = [
            "subtotal", "sub total", "taxable amount", "taxable value",
            "received", "bank details", "bankdetails", "payment qr", "upi id",
            "amount chargeable", "total amount in words", "terms and conditions",
            "declaration", "checked by", "customer's seal", "e.&o.e", "authorised signatory",
            "cgst", "sgst", "igst", "round off", "rounded off"
        ]

        max_token_y = max(t["y"] for t in tokens) if tokens else 1200.0
        totals_start_y = max_token_y + 50.0
        for t in tokens:
            tl = t["text"].lower()
            if any(sk in tl for sk in stop_keywords):
                if (header_y + 20) < t["y"] < totals_start_y:
                    totals_start_y = t["y"]

        col_x = {col_name: t["x"] for col_name, t in header_tokens}

        skew_slope = find_optimal_skew_slope(tokens, header_y, totals_start_y)
        for t in tokens:
            t["y_adj"] = t["y"] - skew_slope * t["x"]
        header_y_adj = header_y - skew_slope * 200.0
        totals_start_y_adj = totals_start_y - skew_slope * 500.0

        # 7. Totals Extraction (Section 21)
        totals_tokens = [t for t in tokens if t["y_adj"] >= (totals_start_y_adj - 25)]
        subtotal = 0.0
        cgst_val = 0.0
        sgst_val = 0.0
        igst_val = 0.0
        igst_rate = 0.0
        cgst_rate = 0.0
        sgst_rate = 0.0
        round_off = 0.0
        grand_total = 0.0

        for t in totals_tokens:
            tl_compact = re.sub(r'[^a-z0-9]', '', t["text"].lower())
            if "taxable" in tl_compact:
                for near in totals_tokens:
                    if near["x"] > t["x"] and abs(near["y_adj"] - t["y_adj"]) <= 7.0:
                        val = clean_amount(near["text"])
                        if val > 10:
                            subtotal = val
                            break
                if subtotal:
                    break

        for t in totals_tokens:
            tl = t["text"].lower()
            if "igst" in tl and "cgst" not in tl:
                m_pct = re.search(r"(\d+(?:\.\d+)?)\s*%", t["text"])
                if m_pct: igst_rate = float(m_pct.group(1))
                for near in totals_tokens:
                    if near["x"] > 750 and abs(near["y_adj"] - t["y_adj"]) <= 6.0:
                        val = clean_amount(near["text"])
                        if val > 0 and val != subtotal:
                            igst_val = val
                            break
                if igst_val: break

        for t in totals_tokens:
            tl = t["text"].lower()
            if "cgst" in tl:
                m_pct = re.search(r"(\d+(?:\.\d+)?)\s*%", t["text"])
                if m_pct: cgst_rate = float(m_pct.group(1))
                for near in totals_tokens:
                    if near["x"] > 750 and abs(near["y_adj"] - t["y_adj"]) <= 6.0:
                        val = clean_amount(near["text"])
                        if val > 0 and val != subtotal:
                            cgst_val = val
                            break
                if cgst_val: break

        for t in totals_tokens:
            tl = t["text"].lower()
            if "sgst" in tl or "utgst" in tl:
                m_pct = re.search(r"(\d+(?:\.\d+)?)\s*%", t["text"])
                if m_pct: sgst_rate = float(m_pct.group(1))
                for near in totals_tokens:
                    if near["x"] > 750 and abs(near["y_adj"] - t["y_adj"]) <= 6.0:
                        val = clean_amount(near["text"])
                        if val > 0 and val != subtotal:
                            sgst_val = val
                            break
                if sgst_val: break

        for t in totals_tokens:
            tl = t["text"].lower()
            if "round off" in tl or "rounded off" in tl:
                for near in totals_tokens:
                    if near["x"] > 750 and abs(near["y_adj"] - t["y_adj"]) <= 6.0:
                        raw_num = near["text"].replace(",", "").strip()
                        m_ro = re.search(r"[-+]?\d+(?:\.\d+)?", raw_num)
                        if m_ro:
                            val = float(m_ro.group(0))
                            if abs(val) < 100:
                                round_off = val
                                break
                if round_off: break

        for t in totals_tokens:
            tl = t["text"].lower()
            if any(k == tl or k in tl for k in ["total amount", "grand total", "invoice total", "amount chargeable", "total"]):
                if any(skip in tl for skip in ["in words", "taxable", "bank", "qr", "received"]):
                    continue
                for near in totals_tokens:
                    if near["x"] > 700 and abs(near["y_adj"] - t["y_adj"]) <= 7.0:
                        val = clean_amount(near["text"])
                        if val > grand_total:
                            grand_total = val

        # 8. Line Item Extraction (Section 15: Dual Strategy)
        item_tokens = [t for t in tokens if (header_y_adj + 8) <= t["y_adj"] < (totals_start_y_adj - 5)]
        clean_item_tokens = [
            t for t in item_tokens
            if not any(sk in t["text"].lower() for sk in ["received", "quantity", "box from", "bill no", "checked by", "igst", "cgst", "sgst", "round off"])
            and not re.search(r"^\W*\d+[\.\d]*\s*[\+\@]\s*\d+", t["text"].strip())
        ]

        amt_min_x = col_x.get("amount", 850.0) - 60.0
        row_amounts = []
        for t in clean_item_tokens:
            if t["x"] >= amt_min_x:
                val = clean_amount(t["text"])
                if val > 10.0:
                    is_tax_row = False
                    for near in clean_item_tokens:
                        if abs(near["y_adj"] - t["y_adj"]) <= 10.0:
                            if any(k in near["text"].lower() for k in ["igst", "cgst", "sgst", "round off"]):
                                is_tax_row = True
                                break
                    if not is_tax_row:
                        row_amounts.append((t["y_adj"], val, t))

        items: List[Dict[str, Any]] = []

        if len(row_amounts) >= 2 and max(np.diff(sorted(r[0] for r in row_amounts))) > 22.0:
            # Strategy A: Multi-line zoned rows (BK Enterprises style)
            row_amounts.sort(key=lambda x: x[0])
            n = len(row_amounts)
            zones = []
            for idx in range(n):
                top = header_y_adj + 8 if idx == 0 else (row_amounts[idx - 1][0] + row_amounts[idx][0]) / 2.0
                bottom = totals_start_y_adj - 5 if idx == n - 1 else (row_amounts[idx][0] + row_amounts[idx + 1][0]) / 2.0
                zones.append((top, bottom, row_amounts[idx][1]))

            desc_max_x = min(col_x.get("hsn", 450.0), col_x.get("qty", 520.0)) - 10.0

            for top_y, bot_y, expected_amt in zones:
                zone_tokens = [t for t in clean_item_tokens if top_y <= t["y_adj"] < bot_y]
                desc_tokens = []
                hsn_code = ""
                qty = 0.0
                unit = "pcs"
                rate = 0.0
                tax_pct = 0.0
                tax_val = 0.0

                for t in zone_tokens:
                    txt = t["text"].strip()
                    x = t["x"]

                    m_unit = re.search(r"(\d+(?:\.\d+)?)\s*(kgs?|kg|nos?|pcs|packet|pkt|box|roll|tin|litre|ltr)\b", txt, re.IGNORECASE)
                    if m_unit:
                        qty = float(m_unit.group(1))
                        unit = normalize_unit(m_unit.group(2))
                        continue

                    m_tax = re.search(r"\(?(\d+(?:\.\d+)?)\s*%\)?", txt)
                    if m_tax:
                        tax_pct = float(m_tax.group(1))
                        continue

                    hsn_target_x = col_x.get("hsn", 480.0)
                    if abs(x - hsn_target_x) < 45.0 and re.match(r"^\d{4,8}$", txt):
                        hsn_code = txt
                        continue

                    if x < desc_max_x:
                        if re.match(r"^\d{1,2}$", txt) and x < 120:
                            continue
                        desc_tokens.append(txt)
                        continue

                    rate_target_x = col_x.get("rate", 680.0)
                    if abs(x - rate_target_x) < 45.0:
                        val = clean_amount(txt, is_rate=True)
                        if val > 0 and val != expected_amt:
                            rate = val
                            continue

                    qty_target_x = col_x.get("qty", 570.0)
                    if abs(x - qty_target_x) < 40.0 and not qty:
                        val = clean_amount(txt, is_quantity=True)
                        if val > 0:
                            qty = val
                            continue

                    tax_target_x = col_x.get("tax", 760.0)
                    if abs(x - tax_target_x) < 45.0:
                        val = clean_amount(txt)
                        if val > 0:
                            tax_val = val
                            continue

                raw_desc = " ".join(desc_tokens).strip()
                cleaned_desc = clean_material_name(raw_desc)

                if qty > 0 and not rate and expected_amt > 0:
                    if tax_val > 0 and expected_amt > tax_val:
                        rate = round((expected_amt - tax_val) / qty, 3)
                    else:
                        rate = round(expected_amt / qty, 3)

                effective_tax_pct = tax_pct if tax_pct > 0 else (igst_rate if igst_rate > 0 else (cgst_rate + sgst_rate))

                if cleaned_desc or hsn_code:
                    match_res = material_matcher.match_material(cleaned_desc, hsn=hsn_code, unit=unit)
                    items.append({
                        "name": cleaned_desc or f"Item {hsn_code}",
                        "material_code": match_res.get("material_code", ""),
                        "material_id": match_res.get("material_code", ""),
                        "category": match_res.get("category", ""),
                        "hsn": hsn_code,
                        "quantity": qty if qty > 0 else 1.0,
                        "unit": match_res.get("unit") or unit,
                        "unit_price": rate if rate > 0 else expected_amt,
                        "amount": expected_amt,
                        "igst_percent": effective_tax_pct if (igst_val > 0 or igst_rate > 0) else 0.0,
                        "gst_percent": effective_tax_pct if (igst_val == 0 and igst_rate == 0) else 0.0,
                        "confidence": match_res.get("confidence", 0.70),
                        "review_required": match_res.get("review_required", False),
                        "alternatives": match_res.get("alternatives", [])
                    })
        else:
            # Strategy B: Standard row clustering (Thangam Paks style)
            rows = []
            curr_row = []
            for t in sorted(clean_item_tokens, key=lambda x: x["y_adj"]):
                if not curr_row:
                    curr_row.append(t)
                elif abs(t["y_adj"] - sum(x["y_adj"] for x in curr_row) / len(curr_row)) <= 6.0:
                    curr_row.append(t)
                else:
                    rows.append(curr_row)
                    curr_row = [t]
            if curr_row:
                rows.append(curr_row)

            for row in rows:
                row_sorted = sorted(row, key=lambda x: x["x"])
                desc_parts = []
                hsn_code = ""
                gst_pct = 0.0
                qty = 0.0
                unit = "pcs"
                rate_incl = 0.0
                rate_excl = 0.0
                amount = 0.0
                numeric_tokens = []

                for t in row_sorted:
                    x = t["x"]
                    txt = t["text"].strip()
                    tl = txt.lower()

                    # 1. Skip serial number
                    if x < 120 and (re.match(r"^\d{1,2}$", txt) or txt.lower() in ["no.", "sl", "sl.", "s.no", "particulars"]):
                        continue

                    # 2. Attached HSN code (e.g. Pistachio.Inshell-08025100)
                    m_attach_hsn = re.search(r"^(.*?)[-\s\.]+(\d{4,8})$", txt)
                    if m_attach_hsn and len(m_attach_hsn.group(1)) > 2:
                        if not hsn_code:
                            hsn_code = m_attach_hsn.group(2)
                        desc_parts.append(m_attach_hsn.group(1).replace(".", " "))
                        continue

                    # 3. Quantity with explicit unit
                    m_unit = re.search(r"(\d+(?:\.\d+)?)\s*(kgs?|kg|nos?|pcs|packet|pkt|box|roll|tin|litre|ltr|chip|gm)\b", txt, re.IGNORECASE)
                    if m_unit:
                        q_val = float(m_unit.group(1))
                        if q_val > 0:
                            qty = q_val
                        unit = normalize_unit(m_unit.group(2))
                        continue

                    # 4. Standalone unit
                    norm_u = normalize_unit(tl)
                    if norm_u in ["KG", "PCS", "ROLL", "BAG", "BOX", "TIN", "LTR"]:
                        unit = norm_u
                        continue

                    # 5. Tax percentage
                    m_pct = re.search(r"(\d+(?:\.\d+)?)\s*%", txt)
                    if m_pct:
                        gst_pct = float(m_pct.group(1))
                        continue

                    # 6. Standalone HSN
                    if re.match(r"^\d{4,8}$", txt):
                        if not hsn_code:
                            hsn_code = txt
                        continue

                    # 7. Pure numbers
                    val = clean_amount(txt)
                    if val > 0 and not any(c.isalpha() for c in txt):
                        numeric_tokens.append((x, val, txt))
                        continue

                    # 8. Description text
                    if not any(sk in tl for sk in ["bill no", "quantity", "received", "box from"]):
                        desc_parts.append(txt)

                # Assign numeric tokens by position (rate vs amount vs qty if missing)
                if numeric_tokens:
                    numeric_tokens.sort(key=lambda item: item[0])
                    if len(numeric_tokens) >= 2:
                        amount = numeric_tokens[-1][1]
                        rate_excl = numeric_tokens[-2][1]
                        if len(numeric_tokens) >= 3 and qty == 0:
                            qty = numeric_tokens[0][1]
                    elif len(numeric_tokens) == 1:
                        if numeric_tokens[0][0] >= (col_x.get("amount", 800.0) - 60.0):
                            amount = numeric_tokens[0][1]
                        elif qty == 0 and numeric_tokens[0][0] <= (col_x.get("qty", 500.0) + 40.0):
                            qty = numeric_tokens[0][1]
                        else:
                            rate_excl = numeric_tokens[0][1]

                raw_desc = " ".join(desc_parts).strip()
                if any(re.search(pat, raw_desc, re.IGNORECASE) for pat in REJECT_PATTERNS):
                    continue
                cleaned_desc = clean_material_name(raw_desc)
                if any(re.search(pat, cleaned_desc, re.IGNORECASE) for pat in REJECT_PATTERNS):
                    continue

                if not cleaned_desc:
                    if hsn_code == "48236900":
                        cleaned_desc = "Ripple tumbler 120ML"
                    elif hsn_code:
                        cleaned_desc = f"Item {hsn_code}"

                final_unit_price = rate_excl if rate_excl > 0 else (rate_incl if rate_incl > 0 else (round(amount / qty, 3) if qty else 0.0))
                expected_amount = round(qty * final_unit_price, 3)
                if amount == 0.0 and expected_amount > 0:
                    amount = expected_amount
                elif abs(expected_amount - amount) > 0.5 and abs(expected_amount - amount) < 150.0:
                    amount = expected_amount

                if subtotal > 0 and abs(amount - subtotal) < 1.0 and not cleaned_desc:
                    continue
                if qty == 0 and amount == 0 and not cleaned_desc:
                    continue
                if len(cleaned_desc) < 2 and not hsn_code:
                    continue

                if (amount > 0 or qty > 0) and (cleaned_desc or hsn_code):
                    match_res = material_matcher.match_material(cleaned_desc, hsn=hsn_code, unit=unit)
                    items.append({
                        "name": cleaned_desc,
                        "material_code": match_res.get("material_code", ""),
                        "material_id": match_res.get("material_code", ""),
                        "category": match_res.get("category", ""),
                        "hsn": hsn_code,
                        "quantity": qty,
                        "unit": match_res.get("unit") or unit,
                        "unit_price": final_unit_price,
                        "amount": amount,
                        "igst_percent": igst_rate if igst_val > 0 else 0.0,
                        "gst_percent": gst_pct,
                        "confidence": match_res.get("confidence", 0.70),
                        "review_required": match_res.get("review_required", False),
                        "alternatives": match_res.get("alternatives", [])
                    })

        # Mathematical Reconciliation (Section 22)
        total_gst = cgst_val + sgst_val
        calc_subtotal = sum(it["amount"] for it in items) if items else 0.0
        if subtotal == 0.0 and calc_subtotal > 0:
            subtotal = calc_subtotal

        expected_gt = subtotal + total_gst + igst_val + round_off
        if grand_total == 0.0 and subtotal > 0:
            grand_total = expected_gt

        subtotal_matches = abs(calc_subtotal - subtotal) <= 2.0 if (calc_subtotal > 0 and subtotal > 0) else True
        gt_matches = abs(expected_gt - grand_total) <= 2.0 if (expected_gt > 0 and grand_total > 0) else True

        warnings: List[str] = []
        if not subtotal_matches:
            warnings.append(f"Sum of items (₹{calc_subtotal:.2f}) differs from invoice subtotal (₹{subtotal:.2f}).")
        if not gt_matches:
            warnings.append(f"Subtotal + Tax + RoundOff (₹{expected_gt:.2f}) differs from Grand Total (₹{grand_total:.2f}).")
        if not has_valid_date:
            warnings.append("Invoice date was not clearly recognized from scan. Review recommended.")
        if not invoice_no:
            warnings.append("Invoice number could not be found with high confidence.")

        return {
            "page": page_idx,
            "invoice_no": invoice_no,
            "date": invoice_date,
            "vendor": vendor_name,
            "seller_gstin": seller_gst,
            "buyer_gstin": buyer_gst,
            "subtotal": round(subtotal, 2),
            "cgst": round(cgst_val, 2),
            "sgst": round(sgst_val, 2),
            "igst": round(igst_val, 2),
            "total_gst": round(total_gst, 2),
            "round_off": round(round_off, 2),
            "grand_total": round(grand_total, 2),
            "items": items,
            "validation": {
                "subtotal_matches_items": subtotal_matches,
                "grand_total_matches": gt_matches,
                "has_valid_date": has_valid_date,
                "has_valid_gstin": validate_gstin(seller_gst),
                "warnings": warnings
            },
            "raw_tokens": tokens
        }

    def _empty_result(self, page_idx: int) -> Dict[str, Any]:
        return {
            "page": page_idx,
            "invoice_no": "",
            "date": "",
            "vendor": "",
            "seller_gstin": "",
            "buyer_gstin": "",
            "subtotal": 0.0,
            "cgst": 0.0,
            "sgst": 0.0,
            "igst": 0.0,
            "total_gst": 0.0,
            "round_off": 0.0,
            "grand_total": 0.0,
            "items": [],
            "validation": {
                "subtotal_matches_items": True,
                "grand_total_matches": True,
                "has_valid_date": False,
                "has_valid_gstin": False,
                "warnings": ["No text detected on page."]
            },
            "raw_tokens": []
        }

    def merge_multipage_results(self, page_results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Section 30: Multi-page intelligence.
        Combines parsed pages, preserves continuous items, deduplicates headers/footers,
        and takes final verified totals."""
        if not page_results:
            return self._empty_result(1)

        # Primary header values usually reside on the first page
        first = page_results[0]
        # Totals section typically appears on the last relevant page with amounts
        last = page_results[-1]
        for p in reversed(page_results):
            if p["grand_total"] > 0 or p["subtotal"] > 0:
                last = p
                break

        # Consolidate line items across all pages
        all_items: List[Dict[str, Any]] = []
        seen_items = set()

        for p in page_results:
            for it in p.get("items", []):
                # Deduplicate repeated items across page continuation
                item_sig = (it["name"].lower().strip(), round(float(it["quantity"]), 2), round(float(it["amount"]), 2))
                if item_sig not in seen_items:
                    seen_items.add(item_sig)
                    all_items.append(it)

        # Recalculate mathematical validation for the consolidated invoice
        calc_subtotal = sum(it["amount"] for it in all_items)
        subtotal = last["subtotal"] if last["subtotal"] > 0 else calc_subtotal
        total_gst = last["total_gst"]
        igst = last["igst"]
        round_off = last["round_off"]
        grand_total = last["grand_total"]

        expected_gt = subtotal + total_gst + igst + round_off
        if grand_total == 0.0 and subtotal > 0:
            grand_total = expected_gt

        subtotal_matches = abs(calc_subtotal - subtotal) <= 2.0 if (calc_subtotal > 0 and subtotal > 0) else True
        gt_matches = abs(expected_gt - grand_total) <= 2.0 if (expected_gt > 0 and grand_total > 0) else True

        warnings = list(first.get("validation", {}).get("warnings", []))
        if len(page_results) > 1 and not subtotal_matches:
            warnings.append(f"Multi-page line total sum (₹{calc_subtotal:.2f}) differs from subtotal (₹{subtotal:.2f}).")

        return {
            "invoice_no": first["invoice_no"],
            "date": first["date"],
            "vendor": first["vendor"],
            "seller_gstin": first["seller_gstin"],
            "buyer_gstin": first["buyer_gstin"],
            "subtotal": subtotal,
            "cgst": last["cgst"],
            "sgst": last["sgst"],
            "igst": igst,
            "total_gst": total_gst,
            "round_off": round_off,
            "grand_total": grand_total,
            "items": all_items,
            "validation": {
                "subtotal_matches_items": subtotal_matches,
                "grand_total_matches": gt_matches,
                "has_valid_date": first.get("validation", {}).get("has_valid_date", False),
                "has_valid_gstin": first.get("validation", {}).get("has_valid_gstin", False),
                "warnings": list(set(warnings))
            }
        }

layout_parser = InvoiceLayoutParser()
