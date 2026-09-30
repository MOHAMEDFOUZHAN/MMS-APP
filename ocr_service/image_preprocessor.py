import cv2
import numpy as np
from typing import Tuple, Dict, Any, List, Optional
from config import config

def evaluate_image_quality(img_bgr: np.ndarray) -> Tuple[bool, Optional[str], Dict[str, Any]]:
    """Section 8: Camera image quality check before running intensive OCR.
    Checks resolution, blur variance, and illumination levels."""
    h, w = img_bgr.shape[:2]
    metrics: Dict[str, Any] = {"width": w, "height": h}

    # 1. Resolution Check
    if w < config.min_image_width or h < config.min_image_height:
        return False, f"Image resolution too low ({w}x{h}). Minimum required: {config.min_image_width}x{config.min_image_height}px.", metrics

    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # 2. Blur Check using Laplacian Variance
    laplacian_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    metrics["blur_score"] = round(laplacian_var, 2)
    if laplacian_var < config.min_blur_score:
        return False, "Image appears excessively blurred or out of focus. Please capture the invoice clearly.", metrics

    # 3. Brightness / Exposure Check
    mean_brightness = float(np.mean(gray))
    metrics["brightness"] = round(mean_brightness, 2)
    if mean_brightness < config.min_brightness:
        return False, "Invoice photo is too dark. Please ensure adequate lighting.", metrics
    if mean_brightness > config.max_brightness:
        return False, "Invoice photo is overexposed or washed out. Please reduce glare.", metrics

    return True, None, metrics

def detect_and_crop_document(img_bgr: np.ndarray) -> np.ndarray:
    """Section 9: Detect document boundary for mobile camera captures and crop unwanted background.
    Only crops if a high-confidence quadrangular document contour is found."""
    h, w = img_bgr.shape[:2]
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(blurred, 50, 150)

    contours, _ = cv2.findContours(edged, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]

    for c in contours:
        area = cv2.contourArea(c)
        # Must occupy at least 35% of total image area
        if area < (h * w * 0.35):
            continue

        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)

        if len(approx) == 4:
            pts = approx.reshape(4, 2).astype("float32")
            # Order points: top-left, top-right, bottom-right, bottom-left
            rect = np.zeros((4, 2), dtype="float32")
            s = pts.sum(axis=1)
            rect[0] = pts[np.argmin(s)]
            rect[2] = pts[np.argmax(s)]
            diff = np.diff(pts, axis=1)
            rect[1] = pts[np.argmin(diff)]
            rect[3] = pts[np.argmax(diff)]

            (tl, tr, br, bl) = rect
            width_a = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
            width_b = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
            max_w = max(int(width_a), int(width_b))

            height_a = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
            height_b = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
            max_h = max(int(height_a), int(height_b))

            if max_w > 400 and max_h > 400:
                dst = np.array([
                    [0, 0],
                    [max_w - 1, 0],
                    [max_w - 1, max_h - 1],
                    [0, max_h - 1]
                ], dtype="float32")

                m = cv2.getPerspectiveTransform(rect, dst)
                warped = cv2.warpPerspective(img_bgr, m, (max_w, max_h))
                return warped

    # If no confident document contour found, return original image safely
    return img_bgr

def normalize_resolution(gray: np.ndarray) -> np.ndarray:
    """Section 6: Resolution normalization rule preserving dot-matrix sharpness:
    width < 850px  -> resize to 1200px (INTER_LINEAR)
    850px-2400px   -> keep original
    width > 2400px -> resize to 2000px (INTER_AREA)"""
    h, w = gray.shape[:2]
    if w < config.scale_min_width:
        scale = float(config.scale_target_small) / float(w)
        return cv2.resize(gray, (config.scale_target_small, int(h * scale)), interpolation=cv2.INTER_LINEAR)
    elif w > config.scale_max_width:
        scale = float(config.scale_target_large) / float(w)
        return cv2.resize(gray, (config.scale_target_large, int(h * scale)), interpolation=cv2.INTER_AREA)
    return gray

def preprocess_variant_a(img_bgr: np.ndarray) -> np.ndarray:
    """Variant A (Default Proven): Grayscale + resolution normalization."""
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY) if len(img_bgr.shape) == 3 else img_bgr.copy()
    return normalize_resolution(gray)

def preprocess_variant_b(img_bgr: np.ndarray) -> np.ndarray:
    """Variant B: Contrast Enhanced using CLAHE."""
    norm = preprocess_variant_a(img_bgr)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(norm)

def preprocess_variant_c(img_bgr: np.ndarray) -> np.ndarray:
    """Variant C: Mild sharpening for faint dot-matrix print."""
    norm = preprocess_variant_a(img_bgr)
    kernel = np.array([
        [0, -0.5, 0],
        [-0.5, 3.0, -0.5],
        [0, -0.5, 0]
    ], dtype=np.float32)
    sharpened = cv2.filter2D(norm, -1, kernel)
    return np.clip(sharpened, 0, 255).astype(np.uint8)

def preprocess_variant_d(img_bgr: np.ndarray) -> np.ndarray:
    """Variant D: Adaptive thresholding / Clean binarization."""
    norm = preprocess_variant_a(img_bgr)
    return cv2.adaptiveThreshold(norm, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 6)

def preprocess_variant_e(img_bgr: np.ndarray) -> np.ndarray:
    """Variant E: Deskewed image via Hough line detection."""
    norm = preprocess_variant_a(img_bgr)
    edges = cv2.Canny(norm, 50, 150, apertureSize=3)
    lines = cv2.HoughLines(edges, 1, np.pi / 180, 200)
    if lines is not None:
        angles = []
        for line in lines[:20]:
            rho, theta = line[0]
            angle = (theta * 180 / np.pi) - 90
            if abs(angle) < 15:
                angles.append(angle)
        if angles:
            median_angle = float(np.median(angles))
            if abs(median_angle) > 0.5:
                h, w = norm.shape[:2]
                center = (w // 2, h // 2)
                m = cv2.getRotationMatrix2D(center, median_angle, 1.0)
                return cv2.warpAffine(norm, m, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    return norm
