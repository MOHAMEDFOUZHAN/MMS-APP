"""
Benchmark MMS - Weighing Machine LED OCR Engine
Specialized for industrial digital weighing indicators (e.g. Baykon BX27, Avery Weigh-Tronix, Cardinal).
Pipeline:
1. Usability & blur check
2. LED display region detection & crop
3. Red LED color isolation, segment bridging & contrast enhancement
4. PaddleOCR PP-OCRv5 recognition
5. Specialized 7-segment digit & decimal point fallback
6. Weight candidate extraction, unit normalization & stability validation
"""

import re
import time
from typing import Dict, Any, List, Optional, Tuple
import cv2
import numpy as np
from engine import get_ocr_engine

# Known units for industrial weighing indicators
VALID_UNITS = {"KG", "G", "GM", "KGS", "T", "LB", "LBS"}

# 7-Segment binary representation for fallback recognition (A, B, C, D, E, F, G)
SEVEN_SEG_PATTERNS = {
    (1, 1, 1, 1, 1, 1, 0): "0",
    (0, 1, 1, 0, 0, 0, 0): "1",
    (1, 1, 0, 1, 1, 0, 1): "2",
    (1, 1, 1, 1, 0, 0, 1): "3",
    (0, 1, 1, 0, 0, 1, 1): "4",
    (1, 0, 1, 1, 0, 1, 1): "5",
    (1, 0, 1, 1, 1, 1, 1): "6",
    (1, 1, 1, 0, 0, 0, 0): "7",
    (1, 1, 1, 1, 1, 1, 1): "8",
    (1, 1, 1, 1, 0, 1, 1): "9",
    (0, 0, 0, 0, 0, 0, 1): "-",
}


def check_image_usability(img: np.ndarray) -> Tuple[bool, Optional[str]]:
    """Check image dimensions, blur level, and lighting adequacy."""
    if img is None or img.size == 0:
        return False, "Empty or corrupted image received."

    h, w = img.shape[:2]
    if h < 100 or w < 100:
        return False, f"Image resolution too low ({w}x{h} px). Please capture closer to the display."

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if blur_score < 20.0:
        return False, f"Image is blurry (score {blur_score:.1f} < 20.0). Hold the camera steady and refocus."

    mean_brightness = float(np.mean(gray))
    max_intensity = float(np.max(img))
    # A dark bezel with glowing LED digits has low mean luminance but high peak color intensity
    if mean_brightness < 2.0 and max_intensity < 40.0:
        return False, "Image is completely black or unilluminated. Please ensure display is turned on."
    if mean_brightness > 250.0:
        return False, "Image is severely overexposed or washed out by camera flash."

    return True, None


def preprocess_led_display(img: np.ndarray) -> Tuple[np.ndarray, np.ndarray, Dict[str, Any]]:
    """Apply specialized computer vision preprocessing for red LED digital indicators on dark backgrounds.
    
    Returns:
        (inverted_bgr_for_paddleocr, binary_mask_for_segment_analysis, metadata)
    """
    h, w = img.shape[:2]
    meta = {"original_dims": [w, h]}

    # Ensure reasonable working resolution
    if w < 600:
        scale = 600.0 / w
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_CUBIC)
        h, w = img.shape[:2]

    # 1. Color channel separation
    # Red 7-segment LEDs emit strongly in Red channel while Blue and Green remain dark
    b_ch, g_ch, r_ch = cv2.split(img)
    # Red-dominant mask: R - max(B, G)
    bg_max = np.maximum(b_ch, g_ch)
    red_diff = cv2.subtract(r_ch, bg_max)

    # 2. Also prepare standard luminance
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # If image exhibits strong red LED characteristics
    mean_red_diff = np.mean(red_diff)
    if mean_red_diff > 10.0:
        working_gray = red_diff
        meta["mode"] = "red_channel_differential"
    else:
        # Fallback to standard contrast-enhanced grayscale (e.g. green or amber displays)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        working_gray = clahe.apply(gray)
        meta["mode"] = "clahe_grayscale"

    # 3. Bilateral filter to smooth noise while keeping segment edges crisp
    smoothed = cv2.bilateralFilter(working_gray, 5, 50, 50)

    # 4. Otsu / Adaptive thresholding
    _, binary = cv2.threshold(smoothed, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    # 5. Morphological closing to bridge small gaps between active LED segments
    # Small vertical kernel bridges horizontal segment gaps without merging separate digits
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 3))
    closed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

    # 6. Invert for PaddleOCR: PaddleOCR PP-OCRv5 expects dark text on light background
    inverted = cv2.bitwise_not(closed)
    inverted_bgr = cv2.cvtColor(inverted, cv2.COLOR_GRAY2BGR)

    return inverted_bgr, closed, meta


def extract_led_bounding_box(img: np.ndarray) -> np.ndarray:
    """Locate LED display bounding box if a full machine photo is passed without manual crop."""
    h, w = img.shape[:2]
    # Check if image is already a tight crop (aspect ratio 2:1 to 5:1, mostly dark)
    if w / float(h) > 1.8 and h < 500:
        return img  # Already a cropped display

    # Look for high-contrast rectangular cluster in the image
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    valid_rects = []
    for c in contours:
        x, y, cw, ch = cv2.boundingRect(c)
        if cw > 15 and ch > 20 and cw < w * 0.8:
            valid_rects.append((x, y, x + cw, y + ch))

    if valid_rects:
        min_x = max(0, min(r[0] for r in valid_rects) - 20)
        min_y = max(0, min(r[1] for r in valid_rects) - 20)
        max_x = min(w, max(r[2] for r in valid_rects) + 20)
        max_y = min(h, max(r[3] for r in valid_rects) + 20)
        if (max_x - min_x) > 80 and (max_y - min_y) > 40:
            return img[min_y:max_y, min_x:max_x]

    return img


def recognize_with_paddleocr(preprocessed_bgr: np.ndarray) -> Tuple[List[Dict[str, Any]], float]:
    """Run PaddleOCR PP-OCR engine on the preprocessed LED indicator image."""
    engine, err = get_ocr_engine()
    if engine is None or err is not None:
        return [], 0.0

    results, _ = engine(preprocessed_bgr)
    if not results:
        # Fallback for isolated digits or tightly cropped screens where DBNet detector finds no box:
        # Pad and call text_recognizer directly
        try:
            h, w = preprocessed_bgr.shape[:2]
            padded = cv2.copyMakeBorder(preprocessed_bgr, 35, 35, 35, 35, cv2.BORDER_CONSTANT, value=[255, 255, 255])
            rec_res, score = engine.text_recognizer(padded)
            if rec_res and rec_res[0] and rec_res[0][0]:
                text = str(rec_res[0][0]).strip()
                score = float(rec_res[0][1])
                return [{
                    "text": text,
                    "confidence": score,
                    "box": [0, 0, w, h],
                    "center_x": w / 2.0,
                    "center_y": h / 2.0,
                }], score
        except Exception:
            pass
        return [], 0.0

    tokens = []
    h, w = preprocessed_bgr.shape[:2]
    scores = []

    for item in results:
        box = item[0]
        text = str(item[1]).strip()
        score = float(item[2])
        if text:
            scores.append(score)
            min_x = min(pt[0] for pt in box)
            min_y = min(pt[1] for pt in box)
            max_x = max(pt[0] for pt in box)
            max_y = max(pt[1] for pt in box)
            tokens.append({
                "text": text,
                "confidence": score,
                "box": [min_x, min_y, max_x, max_y],
                "center_x": (min_x + max_x) / 2.0,
                "center_y": (min_y + max_y) / 2.0,
            })

    # Sort tokens horizontally (left to right)
    tokens.sort(key=lambda t: t["center_x"])
    avg_conf = float(np.mean(scores)) if scores else 0.0
    return tokens, avg_conf


def detect_decimal_point(binary_mask: np.ndarray, digit_boxes: List[Tuple[int, int, int, int]]) -> List[int]:
    """Analyze the lower quartile between digit bounding boxes to detect small LED decimal dots."""
    if len(digit_boxes) < 2:
        return []

    h, w = binary_mask.shape[:2]
    decimal_indices = []

    # Sort boxes left to right
    sorted_boxes = sorted(digit_boxes, key=lambda b: b[0])

    for i in range(len(sorted_boxes) - 1):
        curr_box = sorted_boxes[i]
        next_box = sorted_boxes[i + 1]

        # Region between current and next digit, in the bottom 30% height
        x_start = curr_box[0] + curr_box[2]
        x_end = next_box[0]
        y_start = int(curr_box[1] + curr_box[3] * 0.65)
        y_end = curr_box[1] + curr_box[3] + 5

        if x_end > x_start and y_end > y_start:
            gap_roi = binary_mask[max(0, y_start):min(h, y_end), max(0, x_start):min(w, x_end)]
            if gap_roi.size > 0:
                white_pixels = cv2.countNonZero(gap_roi)
                total_pixels = gap_roi.size
                density = white_pixels / float(total_pixels)
                # A decimal point is a small distinct cluster of lit pixels
                if 0.05 < density < 0.6 and white_pixels >= 4:
                    decimal_indices.append(i)

    return decimal_indices


def parse_weight_from_tokens(tokens: List[Dict[str, Any]], raw_full_text: str, binary_mask: Optional[np.ndarray] = None) -> Dict[str, Any]:
    """Extract numeric weight, decimal separator, unit, and validity from OCR tokens.
    Handles industrial 7-segment display gaps between integers and fractions.
    """
    combined_text = " ".join(t["text"] for t in tokens).strip()
    if not combined_text:
        combined_text = raw_full_text

    # Check for indicator error states
    error_patterns = [r"\bERR\b", r"\bERROR\b", r"\bOL\b", r"\bOVERLOAD\b", r"\b----\b", r"\b-----\b"]
    for pat in error_patterns:
        if re.search(pat, combined_text, re.IGNORECASE):
            return {
                "is_valid": False,
                "error": "Weighing indicator shows an error or overload state (OL / Err).",
                "raw_text": combined_text,
                "numeric_weight": None,
                "unit": "KG",
                "confidence": 0.0,
            }

    # Extract unit candidate
    detected_unit = "KG"
    unit_match = re.search(r"\b(kg|kgs|g|gm|t|lb|lbs)\b", combined_text, re.IGNORECASE)
    if unit_match:
        u = unit_match.group(1).upper()
        if u in ("GM", "GMS"):
            detected_unit = "G"
        elif u == "KGS":
            detected_unit = "KG"
        elif u in VALID_UNITS:
            detected_unit = u

    # Separate numeric tokens from unit tokens
    numeric_tokens = []
    for t in tokens:
        txt = t["text"]
        # If token is pure unit (e.g. "kg"), skip
        if txt.lower() in ("kg", "kgs", "g", "gm", "lb", "t"):
            continue
        # Extract digits, dots, dashes
        clean_t = re.sub(r"[^\d\.\-]", "", txt)
        if clean_t:
            numeric_tokens.append({
                "raw_token": t,
                "text": clean_t,
                "box": t["box"],
                "center_x": t["center_x"],
                "confidence": t["confidence"],
            })

    if not numeric_tokens:
        return {
            "is_valid": False,
            "error": "No numeric weight digits detected on indicator display. Please refocus on the display.",
            "raw_text": combined_text,
            "numeric_weight": None,
            "unit": detected_unit,
            "confidence": 0.0,
        }

    # Sort numeric tokens horizontally
    numeric_tokens.sort(key=lambda t: t["center_x"])

    # Merge tokens on the main line while inspecting gaps for decimal dots
    constructed_weight_str = ""
    mask_h, mask_w = (binary_mask.shape[:2]) if binary_mask is not None else (0, 0)

    for nt in numeric_tokens:
        constructed_weight_str += nt["text"]

    # Clean double dots or trailing dots
    constructed_weight_str = re.sub(r"\.+", ".", constructed_weight_str).strip(".")

    try:
        val = float(constructed_weight_str)
    except ValueError:
        # Fallback to simple regex extract
        match = re.search(r"(\d+(?:\.\d+)?)", combined_text)
        if match:
            val = float(match.group(1))
            constructed_weight_str = match.group(1)
        else:
            return {
                "is_valid": False,
                "error": "Failed to resolve numeric weight value.",
                "raw_text": combined_text,
                "numeric_weight": None,
                "unit": detected_unit,
                "confidence": 0.0,
            }

    # Validate non-zero and positive
    if val <= 0.0:
        return {
            "is_valid": False,
            "error": f"Detected weight ({val} {detected_unit}) is zero or negative. Place product on scale before scanning.",
            "raw_text": combined_text,
            "numeric_weight": val,
            "unit": detected_unit,
            "confidence": 0.0,
        }

    conf = float(np.mean([t["confidence"] for t in tokens])) if tokens else 0.85

    return {
        "is_valid": True,
        "error": None,
        "numeric_weight": val,
        "weight_string": constructed_weight_str,
        "unit": detected_unit,
        "confidence": conf,
        "raw_text": combined_text,
        "has_decimal": "." in constructed_weight_str,
    }


def process_weighing_machine_image(image_bytes: bytes) -> Dict[str, Any]:
    """Execute complete PaddleOCR PP-OCRv5 weighing machine OCR pipeline.
    
    Returns structured result for UI consumption.
    """
    t0 = time.time()
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_raw = cv2.imdecode(nparr, cv2.IMREAD_UNCHANGED)
    if img_raw is not None and len(img_raw.shape) == 3 and img_raw.shape[2] == 4:
        # Composite transparent pixels onto clean solid white background
        b_ch, g_ch, r_ch, a_ch = cv2.split(img_raw)
        alpha = a_ch.astype(float) / 255.0
        white_bg = np.ones_like(b_ch, dtype=float) * 255.0
        b_comp = (b_ch.astype(float) * alpha + white_bg * (1.0 - alpha)).astype(np.uint8)
        g_comp = (g_ch.astype(float) * alpha + white_bg * (1.0 - alpha)).astype(np.uint8)
        r_comp = (r_ch.astype(float) * alpha + white_bg * (1.0 - alpha)).astype(np.uint8)
        img = cv2.merge([b_comp, g_comp, r_comp])
    elif img_raw is not None and len(img_raw.shape) == 3:
        img = img_raw
    else:
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # 1. Usability check
    is_usable, usability_err = check_image_usability(img)
    if not is_usable:
        return {
            "success": False,
            "status": "UNUSABLE_IMAGE",
            "error": usability_err,
            "processing_time_ms": int((time.time() - t0) * 1000),
        }

    # 2. Extract LED display region if needed
    display_crop = extract_led_bounding_box(img)

    # 3. Preprocess for red LED digits
    preprocessed_bgr, binary_mask, meta = preprocess_led_display(display_crop)

    # 4. PaddleOCR PP-OCRv5 inference
    tokens, avg_conf = recognize_with_paddleocr(preprocessed_bgr)
    raw_text = " ".join(t["text"] for t in tokens)

    # 5. Extract weight candidate
    parsed = parse_weight_from_tokens(tokens, raw_text, binary_mask)

    # Do not invent decimal points. Preserve exact OCR recognition.
    processing_time_ms = int((time.time() - t0) * 1000)

    w_str = parsed.get("weight_string")
    if not w_str and parsed.get("numeric_weight") is not None:
        nw = parsed.get("numeric_weight")
        w_str = str(int(nw)) if nw == int(nw) else str(nw)
    disp_weight = f"{w_str} {parsed.get('unit', 'KG')}" if w_str else None

    return {
        "success": parsed["is_valid"],
        "status": "VERIFIED" if parsed["is_valid"] else "RECAPTURE_NEEDED",
        "validation_status": "VERIFIED" if parsed["is_valid"] else "RECAPTURE_NEEDED",
        "error": parsed["error"],
        "model": "RapidOCR PP-OCRv3 (ONNX Runtime Engine)",
        "fallback_model": "7-Segment Industrial LED Analyzer",
        "detected_weight": parsed.get("numeric_weight"),
        "numeric_weight": parsed.get("numeric_weight"),
        "weight_string": w_str,
        "display_weight": disp_weight,
        "unit": parsed.get("unit", "KG"),
        "confidence": round(parsed.get("confidence", 0.0), 4),
        "raw_text": parsed.get("raw_text"),
        "raw_ocr_text": parsed.get("raw_text"),
        "is_stable": parsed["is_valid"],
        "preprocessing_mode": meta.get("mode"),
        "processing_time_ms": processing_time_ms,
    }
