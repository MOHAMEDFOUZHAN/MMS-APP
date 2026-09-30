import io
from typing import List, Tuple, Optional
import numpy as np
from PIL import Image
import cv2

try:
    import pypdfium2 as pdfium
except ImportError:
    pdfium = None

from config import config

def is_pdf(file_bytes: bytes) -> bool:
    """Check if byte payload starts with the standard PDF magic header."""
    return file_bytes.startswith(b"%PDF")

def render_pdf_to_images(file_bytes: bytes, scale: Optional[float] = None) -> List[np.ndarray]:
    """Section 5: Multi-page PDF rendering via pypdfium2.
    Renders every page (Page 1, 2, ... N) into numpy BGR array.
    Prevents the single-page limitation of the old system."""
    if pdfium is None:
        raise RuntimeError("pypdfium2 is required for PDF invoice processing.")

    render_scale = scale or config.pdf_render_scale

    try:
        pdf = pdfium.PdfDocument(file_bytes)
    except Exception as e:
        raise ValueError(f"Corrupt or unreadable PDF document: {e}")

    num_pages = len(pdf)
    if num_pages == 0:
        raise ValueError("PDF document has 0 pages.")

    max_pages = min(num_pages, config.max_pdf_pages)
    page_images: List[np.ndarray] = []

    for i in range(max_pages):
        try:
            page = pdf[i]
            pil_img = page.render(scale=render_scale).to_pil()
            rgb_arr = np.array(pil_img)
            bgr_arr = cv2.cvtColor(rgb_arr, cv2.COLOR_RGB2BGR)
            page_images.append(bgr_arr)
        except Exception as e:
            print(f"Warning: Failed to render page {i+1} of PDF: {e}")

    if not page_images:
        raise ValueError("Failed to render any page from the PDF document.")

    return page_images
