import re
import time
import requests
from typing import Dict, Any, List, Optional, Tuple
from config import config

class SupabaseMaterialMatcher:
    def __init__(self):
        self.materials_cache: List[Dict[str, Any]] = []
        self.aliases_cache: Dict[str, Dict[str, Any]] = {}
        self.last_fetch_time: float = 0.0
        self.cache_ttl: float = 300.0  # 5 minutes cache

        # Fallback in-memory aliases if database table is initializing
        self.static_aliases: Dict[str, Dict[str, Any]] = {
            "buttefly": {"canonical": "BUTTERFLY", "code": None},
            "kosherking napkin": {"canonical": "KOSHER KING NAPKIN", "code": "900"},
            "woodenspoonsmall": {"canonical": "WOODEN SPOON SMALL", "code": "901"},
            "woodenspoon": {"canonical": "WOODEN SPOON", "code": "901"},
            "petjar": {"canonical": "PET JAR", "code": "902"},
            "ldcover": {"canonical": "LD COVER", "code": "903"},
            "4ldcover": {"canonical": "LD COVER", "code": "903"},
            "st.pouch": {"canonical": "ST. POUCH", "code": "904"},
            "st.pouch brown": {"canonical": "ST. POUCH BROWN", "code": "904"},
            "collo tape": {"canonical": "CELLO TAPE", "code": "905"},
            "cellotape": {"canonical": "CELLO TAPE", "code": "905"},
            "collo": {"canonical": "CELLO", "code": "905"},
            "paperstraw": {"canonical": "PAPER STRAW", "code": "908"},
            "9paper": {"canonical": "PAPER", "code": None},
            "rippletumbler": {"canonical": "RIPPLE TUMBLER", "code": "910"},
            "rown tape": {"canonical": "BROWN TAPE", "code": "907"},
            "pet jar - 600ml": {"canonical": "PET JAR - 500ML", "code": "902"},
        }

    def _refresh_cache_if_needed(self):
        now = time.time()
        if self.materials_cache and (now - self.last_fetch_time) < self.cache_ttl:
            return

        headers = {
            "apikey": config.supabase_key,
            "Authorization": f"Bearer {config.supabase_key}",
            "Content-Type": "application/json"
        }

        # 1. Fetch Material Master
        try:
            url = f"{config.supabase_url}/rest/v1/materials?select=material_code,description,category,unit,hsn_sac,grade"
            res = requests.get(url, headers=headers, timeout=5)
            if res.status_code == 200:
                data = res.json()
                if isinstance(data, list) and len(data) > 0:
                    # Deduplicate by material_code
                    dedup: Dict[str, Dict[str, Any]] = {}
                    for row in data:
                        code = str(row.get("material_code", "")).strip()
                        if code and code not in dedup:
                            dedup[code] = row
                    self.materials_cache = list(dedup.values())
                    self.last_fetch_time = now
        except Exception as e:
            print(f"Warning: Failed to fetch materials from Supabase: {e}")

        # 2. Fetch Material Aliases (Section 27)
        try:
            url_aliases = f"{config.supabase_url}/rest/v1/material_aliases?select=alias_pattern,canonical_text,material_code,category"
            res_a = requests.get(url_aliases, headers=headers, timeout=4)
            if res_a.status_code == 200:
                data_a = res_a.json()
                if isinstance(data_a, list):
                    for a in data_a:
                        pattern = str(a.get("alias_pattern", "")).strip().lower()
                        if pattern:
                            self.aliases_cache[pattern] = {
                                "canonical": a.get("canonical_text", ""),
                                "code": a.get("material_code")
                            }
        except Exception as e:
            # Fall back to static aliases
            self.aliases_cache = self.static_aliases

    def match_material(
        self,
        ocr_description: str,
        hsn: Optional[str] = None,
        unit: Optional[str] = None,
        category: Optional[str] = None
    ) -> Dict[str, Any]:
        """Resolve an OCR material description against the Supabase Material Master.
        Returns structured match candidate dictionary with confidence and alternative options."""
        self._refresh_cache_if_needed()

        if not ocr_description:
            return {
                "matched": False,
                "material_code": "",
                "description": "",
                "category": "",
                "unit": unit or "pcs",
                "confidence": 0.0,
                "review_required": True,
                "alternatives": []
            }

        norm_input = re.sub(r'[^a-zA-Z0-9\s]', ' ', ocr_description).lower()
        norm_input = re.sub(r'\s+', ' ', norm_input).strip()

        # 1. Alias lookup (Section 27)
        alias_canonical = None
        alias_direct_code = None

        all_aliases = {**self.static_aliases, **self.aliases_cache}
        for alias_key, alias_val in all_aliases.items():
            if alias_key in norm_input:
                alias_canonical = alias_val["canonical"]
                alias_direct_code = alias_val["code"]
                break

        if alias_direct_code:
            for m in self.materials_cache:
                if str(m.get("material_code")) == str(alias_direct_code):
                    return {
                        "matched": True,
                        "material_code": m["material_code"],
                        "description": m["description"],
                        "category": m["category"],
                        "unit": m["unit"],
                        "confidence": 0.95,
                        "review_required": False,
                        "alternatives": []
                    }

        target_desc = (alias_canonical or ocr_description).strip().lower()
        target_norm = re.sub(r'[^a-zA-Z0-9\s]', ' ', target_desc)
        target_norm = re.sub(r'\s+', ' ', target_norm).strip()

        # 2. Exact match (case-insensitive)
        for m in self.materials_cache:
            m_desc = str(m.get("description") or "").strip().lower()
            m_norm = re.sub(r'[^a-zA-Z0-9\s]', ' ', m_desc)
            m_norm = re.sub(r'\s+', ' ', m_norm).strip()

            if target_norm == m_norm or target_desc == m_desc:
                # Cross-field consistency boost (Section 29)
                conf = 0.98
                if hsn and m.get("hsn_sac") and hsn == m.get("hsn_sac"):
                    conf = 1.0
                return {
                    "matched": True,
                    "material_code": m["material_code"],
                    "description": m["description"],
                    "category": m["category"],
                    "unit": m["unit"],
                    "confidence": conf,
                    "review_required": False,
                    "alternatives": []
                }

        # 3. Prefix & Substring Match
        prefix_matches = []
        for m in self.materials_cache:
            m_desc = str(m.get("description") or "").strip().lower()
            m_norm = re.sub(r'[^a-zA-Z0-9\s]', ' ', m_desc)
            m_norm = re.sub(r'\s+', ' ', m_norm).strip()

            if m_norm.startswith(target_norm) or target_norm.startswith(m_norm):
                prefix_matches.append((m, 0.92))
            elif target_norm in m_norm or m_norm in target_norm:
                prefix_matches.append((m, 0.85))

        if prefix_matches:
            prefix_matches.sort(key=lambda x: x[1], reverse=True)
            best_m, best_score = prefix_matches[0]
            alts = [
                {"material_code": x[0]["material_code"], "description": x[0]["description"], "confidence": x[1]}
                for x in prefix_matches[1:4]
            ]
            return {
                "matched": True,
                "material_code": best_m["material_code"],
                "description": best_m["description"],
                "category": best_m["category"],
                "unit": best_m["unit"],
                "confidence": best_score,
                "review_required": len(prefix_matches) > 1 and (best_score < 0.90),
                "alternatives": alts
            }

        # 4. Multi-word Intersection & Reverse Containment (Proven Old Logic)
        stopwords = {'dried', 'fresh', 'organic', 'powder', 'extract', 'tbc', 'leaf', 'leaves', 'flower', 'flowers', 'tea', 'item', 'the', 'and', 'with', 'for'}
        input_words = [w for w in re.findall(r'[a-zA-Z0-9]+', target_norm) if len(w) >= 2]
        meaningful_words = [w for w in input_words if w not in stopwords]
        search_words = meaningful_words if meaningful_words else input_words

        candidates: Dict[str, Dict[str, Any]] = {}
        for m in self.materials_cache:
            m_code = m["material_code"]
            m_desc = str(m.get("description") or "").lower()
            m_words = set(re.findall(r'[a-zA-Z0-9]+', m_desc))

            common = m_words.intersection(set(search_words))
            if common:
                score = len(common) * 1.5

                # Reverse containment: if key words of material description are contained in OCR line
                m_meaningful = [dw for dw in m_words if dw not in stopwords and len(dw) >= 3]
                if m_meaningful and all(dw in target_norm for dw in m_meaningful):
                    score += 5.0

                # Cross-field HSN bonus (Section 29)
                if hsn and m.get("hsn_sac") and hsn == m.get("hsn_sac"):
                    score += 3.0

                # Cross-field Unit bonus (Section 29)
                if unit and m.get("unit") and unit.lower() == str(m.get("unit")).lower():
                    score += 1.0

                candidates[m_code] = {"material": m, "score": score}

        if candidates:
            ranked = sorted(candidates.values(), key=lambda c: c["score"], reverse=True)
            best_cand = ranked[0]
            best_m = best_cand["material"]
            score = best_cand["score"]

            confidence = min(0.90, max(0.50, score / 8.0))

            alts = [
                {
                    "material_code": c["material"]["material_code"],
                    "description": c["material"]["description"],
                    "confidence": round(min(0.85, c["score"] / 8.0), 2)
                }
                for c in ranked[1:4]
            ]

            # Section 28: If multiple candidates have similar high scores, require review
            review_req = len(ranked) > 1 and (ranked[0]["score"] - ranked[1]["score"] < 1.5)
            if confidence < 0.75:
                review_req = True

            return {
                "matched": True,
                "material_code": best_m["material_code"],
                "description": best_m["description"],
                "category": best_m["category"],
                "unit": best_m["unit"],
                "confidence": round(confidence, 2),
                "review_required": review_req,
                "alternatives": alts
            }

        # 5. No reliable match found
        return {
            "matched": False,
            "material_code": "",
            "description": ocr_description,
            "category": category or "",
            "unit": unit or "pcs",
            "confidence": 0.20,
            "review_required": True,
            "alternatives": []
        }

material_matcher = SupabaseMaterialMatcher()
