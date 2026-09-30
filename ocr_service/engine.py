import os
import threading
from typing import Optional, Tuple, List, Any
import numpy as np
from rapidocr_onnxruntime import RapidOCR

_engine_lock = threading.Lock()
_cached_engine: Optional[RapidOCR] = None
_init_error: Optional[str] = None

def get_ocr_engine() -> Tuple[Optional[RapidOCR], Optional[str]]:
    """Thread-safe singleton accessor for RapidOCR PP-OCRv3 engine.
    Ensures models are loaded once into memory (Section 35) and shared across worker tasks."""
    global _cached_engine, _init_error
    if _cached_engine is not None:
        return _cached_engine, None

    with _engine_lock:
        if _cached_engine is not None:
            return _cached_engine, None

        try:
            # RapidOCR by default discovers models from its site-packages/rapidocr_onnxruntime/models directory
            # Verify and instantiate
            engine = RapidOCR()
            _cached_engine = engine
            _init_error = None
            return _cached_engine, None
        except Exception as e:
            _init_error = f"RapidOCR PP-OCRv3 initialization failed: {e}"
            return None, _init_error

def run_ocr_on_image(image_arr: np.ndarray) -> Tuple[List[dict], float]:
    """Execute OCR inference on preprocessed image array.
    Returns:
        (tokens, average_confidence)
        Each token contains: text, x, y, score, box
    """
    engine, err = get_ocr_engine()
    if engine is None or err is not None:
        raise RuntimeError(err or "OCR engine is unavailable")

    import time
    t0 = time.time()
    results, _ = engine(image_arr)
    duration = time.time() - t0

    if not results:
        return [], 0.0

    tokens = []
    h, w = image_arr.shape[:2]
    scores = []

    for item in results:
        box = item[0]
        text = str(item[1]).strip()
        score = float(item[2])
        if text:
            scores.append(score)
            avg_x = sum(pt[0] for pt in box) / 4.0
            avg_y = sum(pt[1] for pt in box) / 4.0
            # Virtual 1000x1000 coordinate space (Section 10)
            tokens.append({
                "text": text,
                "x": (avg_x / w) * 1000.0,
                "y": (avg_y / h) * 1000.0,
                "score": score,
                "box": box,
                "raw_width": w,
                "raw_height": h
            })

    # Sort top-to-bottom, left-to-right
    tokens.sort(key=lambda t: (t["y"], t["x"]))
    avg_conf = float(np.mean(scores)) if scores else 0.0
    return tokens, avg_conf
