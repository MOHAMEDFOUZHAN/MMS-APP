import os
import uuid
import time
import threading
from typing import Dict, Any, List, Optional
import numpy as np
import cv2

from config import config
from image_preprocessor import (
    evaluate_image_quality, detect_and_crop_document,
    preprocess_variant_a, preprocess_variant_b, preprocess_variant_c,
    preprocess_variant_d, preprocess_variant_e
)
from engine import run_ocr_on_image
from layout_parser import layout_parser
from pdf_handler import is_pdf, render_pdf_to_images
from material_matcher import material_matcher

class OcrJobState:
    UPLOADING = "UPLOADING"
    QUEUED = "QUEUED"
    PROCESSING = "PROCESSING"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"

class OcrJob:
    def __init__(self, job_id: str, document_type: str = "invoice"):
        self.job_id = job_id
        self.document_type = document_type
        self.state = OcrJobState.QUEUED
        self.progress_message = "Queued for processing..."
        self.progress_percent = 0.0
        self.created_at = time.time()
        self.completed_at: Optional[float] = None
        self.result: Optional[Dict[str, Any]] = None
        self.error: Optional[str] = None
        self.pages_processed = 0
        self.total_pages = 0

class OcrBackgroundWorker:
    def __init__(self):
        self._jobs: Dict[str, OcrJob] = {}
        self._lock = threading.Lock()

    def create_job(self, document_type: str = "invoice") -> OcrJob:
        job_id = f"OCR-{int(time.time())}-{uuid.uuid4().hex[:6].upper()}"
        job = OcrJob(job_id=job_id, document_type=document_type)
        with self._lock:
            self._jobs[job_id] = job
        return job

    def get_job(self, job_id: str) -> Optional[OcrJob]:
        with self._lock:
            return self._jobs.get(job_id)

    def submit_file_processing(self, job_id: str, file_bytes: bytes, filename: str):
        thread = threading.Thread(
            target=self._process_file_job,
            args=(job_id, file_bytes, filename),
            daemon=True
        )
        thread.start()

    def submit_multipage_processing(self, job_id: str, files_list: List[Tuple[str, bytes]]):
        thread = threading.Thread(
            target=self._process_multipage_job,
            args=(job_id, files_list),
            daemon=True
        )
        thread.start()

    def _process_file_job(self, job_id: str, file_bytes: bytes, filename: str):
        job = self.get_job(job_id)
        if not job:
            return

        try:
            job.state = OcrJobState.PROCESSING
            job.progress_message = "Evaluating document format..."
            job.progress_percent = 0.10

            # 1. Render pages if PDF or decode image
            page_images: List[np.ndarray] = []
            if is_pdf(file_bytes) or filename.lower().endswith(".pdf"):
                job.progress_message = "Rendering multi-page PDF with PDFium..."
                job.progress_percent = 0.15
                page_images = render_pdf_to_images(file_bytes)
            else:
                job.progress_message = "Decoding camera/scanned image..."
                job.progress_percent = 0.15
                arr = np.frombuffer(file_bytes, dtype=np.uint8)
                img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                if img is None:
                    raise ValueError("Failed to decode uploaded image file.")
                
                # Check quality for camera capture (Section 8)
                ok, warn, metrics = evaluate_image_quality(img)
                if not ok:
                    job.state = OcrJobState.REVIEW_REQUIRED
                    job.progress_message = warn or "Low image quality detected"
                    job.error = warn
                    job.result = {
                        "success": False,
                        "job_id": job_id,
                        "quality_warning": warn,
                        "metrics": metrics
                    }
                    return

                # Detect boundaries and crop if appropriate (Section 9)
                cropped = detect_and_crop_document(img)
                page_images = [cropped]

            job.total_pages = len(page_images)
            page_results: List[Dict[str, Any]] = []

            for idx, page_img in enumerate(page_images):
                p_num = idx + 1
                job.progress_message = f"Processing page {p_num}/{job.total_pages} with RapidOCR PP-OCRv3..."
                pct_start = 0.20 + (idx / job.total_pages) * 0.50
                job.progress_percent = pct_start

                # Multi-pass Adaptive Preprocessing & Execution (Section 7 & 24)
                parsed_page = self._process_page_adaptive(page_img, p_num)
                page_results.append(parsed_page)
                job.pages_processed = p_num

            job.progress_message = "Combining line items and reconciling totals..."
            job.progress_percent = 0.85

            # Combine multi-page results
            combined = layout_parser.merge_multipage_results(page_results)

            job.progress_message = "Evaluating field-level confidence..."
            job.progress_percent = 0.95

            # Compute field-level confidence (Section 23)
            confidence_analysis = self._compute_confidence_analysis(combined, page_results)

            has_review_flags = (
                confidence_analysis["overall_status"] in ("REVIEW_REQUIRED", "LOW") or
                not combined.get("validation", {}).get("subtotal_matches_items", True) or
                not combined.get("validation", {}).get("grand_total_matches", True) or
                any(it.get("review_required", False) for it in combined.get("items", []))
            )

            job.state = OcrJobState.REVIEW_REQUIRED if has_review_flags else OcrJobState.COMPLETED
            job.progress_message = "Processing complete."
            job.progress_percent = 1.0
            job.completed_at = time.time()
            job.result = {
                "success": True,
                "job_id": job_id,
                "document_type": job.document_type,
                "pages_processed": job.pages_processed,
                "invoice": {
                    "invoice_no": combined.get("invoice_no", ""),
                    "date": combined.get("date", ""),
                    "vendor": combined.get("vendor", ""),
                    "seller_gstin": combined.get("seller_gstin", ""),
                    "buyer_gstin": combined.get("buyer_gstin", ""),
                    "subtotal": combined.get("subtotal", 0.0),
                    "cgst": combined.get("cgst", 0.0),
                    "sgst": combined.get("sgst", 0.0),
                    "igst": combined.get("igst", 0.0),
                    "total_gst": combined.get("total_gst", 0.0),
                    "round_off": combined.get("round_off", 0.0),
                    "grand_total": combined.get("grand_total", 0.0)
                },
                "items": combined.get("items", []),
                "validation": combined.get("validation", {}),
                "confidence": confidence_analysis
            }

        except Exception as e:
            job.state = OcrJobState.FAILED
            job.error = str(e)
            job.progress_message = f"Error during OCR processing: {e}"
            job.completed_at = time.time()

    def _process_multipage_job(self, job_id: str, files_list: List[Tuple[str, bytes]]):
        job = self.get_job(job_id)
        if not job:
            return

        try:
            job.state = OcrJobState.PROCESSING
            job.total_pages = len(files_list)
            job.progress_message = f"Decoding {job.total_pages} captured pages..."
            job.progress_percent = 0.10

            page_images: List[np.ndarray] = []
            for fname, fbytes in files_list:
                if is_pdf(fbytes) or fname.lower().endswith(".pdf"):
                    page_images.extend(render_pdf_to_images(fbytes))
                else:
                    arr = np.frombuffer(fbytes, dtype=np.uint8)
                    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
                    if img is not None:
                        cropped = detect_and_crop_document(img)
                        page_images.append(cropped)

            job.total_pages = len(page_images)
            page_results: List[Dict[str, Any]] = []

            for idx, page_img in enumerate(page_images):
                p_num = idx + 1
                job.progress_message = f"Processing Page {p_num} of {job.total_pages}..."
                job.progress_percent = 0.20 + (idx / job.total_pages) * 0.60

                parsed_page = self._process_page_adaptive(page_img, p_num)
                page_results.append(parsed_page)
                job.pages_processed = p_num

            job.progress_message = "Merging continuation pages and removing repeated headers..."
            job.progress_percent = 0.88

            combined = layout_parser.merge_multipage_results(page_results)
            confidence_analysis = self._compute_confidence_analysis(combined, page_results)

            has_review_flags = (
                confidence_analysis["overall_status"] in ("REVIEW_REQUIRED", "LOW") or
                not combined.get("validation", {}).get("subtotal_matches_items", True) or
                not combined.get("validation", {}).get("grand_total_matches", True) or
                any(it.get("review_required", False) for it in combined.get("items", []))
            )

            job.state = OcrJobState.REVIEW_REQUIRED if has_review_flags else OcrJobState.COMPLETED
            job.progress_message = "Multi-page processing complete."
            job.progress_percent = 1.0
            job.completed_at = time.time()
            job.result = {
                "success": True,
                "job_id": job_id,
                "document_type": "multi_page_invoice",
                "pages_processed": job.pages_processed,
                "invoice": {
                    "invoice_no": combined.get("invoice_no", ""),
                    "date": combined.get("date", ""),
                    "vendor": combined.get("vendor", ""),
                    "seller_gstin": combined.get("seller_gstin", ""),
                    "buyer_gstin": combined.get("buyer_gstin", ""),
                    "subtotal": combined.get("subtotal", 0.0),
                    "cgst": combined.get("cgst", 0.0),
                    "sgst": combined.get("sgst", 0.0),
                    "igst": combined.get("igst", 0.0),
                    "total_gst": combined.get("total_gst", 0.0),
                    "round_off": combined.get("round_off", 0.0),
                    "grand_total": combined.get("grand_total", 0.0)
                },
                "items": combined.get("items", []),
                "validation": combined.get("validation", {}),
                "confidence": confidence_analysis
            }

        except Exception as e:
            job.state = OcrJobState.FAILED
            job.error = str(e)
            job.progress_message = f"Error in multi-page processing: {e}"
            job.completed_at = time.time()

    def _process_page_adaptive(self, img_bgr: np.ndarray, page_num: int) -> Dict[str, Any]:
        """Adaptive Multi-Pass OCR Execution (Sections 7, 24).
        Runs Variant A first. If confidence is low or required fields are missing,
        triggers Variant B/C/E and compares results."""
        # 1. First Pass: Variant A (Grayscale + Normalization)
        var_a = preprocess_variant_a(img_bgr)
        tokens_a, conf_a = run_ocr_on_image(var_a)
        res_a = layout_parser.parse_single_page(tokens_a, page_idx=page_num)

        # Evaluate if second pass is required
        needs_second_pass = (
            conf_a < 0.85 or
            (not res_a.get("invoice_no") and page_num == 1) or
            (not res_a.get("vendor") and page_num == 1) or
            len(res_a.get("items", [])) == 0 or
            not res_a.get("validation", {}).get("grand_total_matches", True)
        )

        if not needs_second_pass:
            res_a["ocr_confidence"] = conf_a
            res_a["pass_count"] = 1
            return res_a

        # 2. Second Pass: Variant B (Contrast Enhanced) or Variant C (Sharpened)
        var_b = preprocess_variant_b(img_bgr)
        tokens_b, conf_b = run_ocr_on_image(var_b)
        res_b = layout_parser.parse_single_page(tokens_b, page_idx=page_num)

        # Compare Passes (Section 24)
        merged = res_a.copy()
        merged["pass_count"] = 2
        merged["ocr_confidence"] = max(conf_a, conf_b)

        # If Variant B successfully found invoice_no and Variant A did not
        if not merged.get("invoice_no") and res_b.get("invoice_no"):
            merged["invoice_no"] = res_b["invoice_no"]

        # If Variant B found vendor and Variant A did not
        if not merged.get("vendor") and res_b.get("vendor"):
            merged["vendor"] = res_b["vendor"]

        # If Variant B found items and Variant A found fewer/none
        if len(res_b.get("items", [])) > len(merged.get("items", [])):
            merged["items"] = res_b["items"]
            merged["subtotal"] = res_b["subtotal"]
            merged["grand_total"] = res_b["grand_total"]
            merged["validation"] = res_b["validation"]

        # Boost confidence if both agree
        if res_a.get("invoice_no") and res_a.get("invoice_no") == res_b.get("invoice_no"):
            merged["ocr_confidence"] = min(1.0, merged["ocr_confidence"] + 0.05)

        return merged

    def _compute_confidence_analysis(self, combined: Dict[str, Any], page_results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Field-level confidence scoring (Section 23 & 25)."""
        fields = {}

        # 1. Invoice Number
        inv_no = combined.get("invoice_no", "")
        if inv_no:
            conf = 0.96 if len(inv_no) >= 3 else 0.80
            fields["invoice_no"] = {
                "value": inv_no,
                "confidence": conf,
                "status": "HIGH" if conf >= 0.90 else "MEDIUM"
            }
        else:
            fields["invoice_no"] = {
                "value": "",
                "confidence": 0.0,
                "status": "REVIEW_REQUIRED",
                "warning": "Missing invoice number"
            }

        # 2. Date
        dt = combined.get("date", "")
        has_valid_dt = combined.get("validation", {}).get("has_valid_date", False)
        fields["date"] = {
            "value": dt,
            "confidence": 0.95 if has_valid_dt else 0.40,
            "status": "HIGH" if has_valid_dt else "REVIEW_REQUIRED",
            "warning": None if has_valid_dt else "Date not recognized with certainty"
        }

        # 3. Vendor
        vnd = combined.get("vendor", "")
        fields["vendor"] = {
            "value": vnd,
            "confidence": 0.92 if len(vnd) > 3 else 0.60,
            "status": "HIGH" if len(vnd) > 3 else "MEDIUM"
        }

        # 4. GSTIN
        gst = combined.get("seller_gstin", "")
        has_gst = combined.get("validation", {}).get("has_valid_gstin", False)
        fields["seller_gstin"] = {
            "value": gst,
            "confidence": 0.97 if has_gst else (0.75 if gst else 0.0),
            "status": "HIGH" if has_gst else ("MEDIUM" if gst else "LOW")
        }

        # 5. Grand Total & Subtotal
        gt_matches = combined.get("validation", {}).get("grand_total_matches", True)
        gt_val = combined.get("grand_total", 0.0)
        fields["grand_total"] = {
            "value": gt_val,
            "confidence": 0.98 if (gt_matches and gt_val > 0) else 0.65,
            "status": "HIGH" if (gt_matches and gt_val > 0) else "REVIEW_REQUIRED",
            "warning": None if gt_matches else "Mathematical reconciliation difference detected"
        }

        # Overall Status
        all_confs = [f["confidence"] for f in fields.values()]
        avg_conf = float(np.mean(all_confs)) if all_confs else 0.0

        if any(f["status"] == "REVIEW_REQUIRED" for f in fields.values()):
            overall_status = "REVIEW_REQUIRED"
        elif avg_conf >= 0.90:
            overall_status = "HIGH"
        elif avg_conf >= 0.75:
            overall_status = "MEDIUM"
        else:
            overall_status = "LOW"

        return {
            "overall_confidence": round(avg_conf, 2),
            "overall_status": overall_status,
            "fields": fields
        }

ocr_worker = OcrBackgroundWorker()
