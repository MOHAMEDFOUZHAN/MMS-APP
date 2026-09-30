import os
from dataclasses import dataclass

@dataclass
class OcrConfig:
    # Supabase Connection
    supabase_url: str = os.getenv("SUPABASE_URL", "https://japxiaxyabhhhclphbqr.supabase.co")
    supabase_key: str = os.getenv("SUPABASE_PUBLISHABLE_KEY", os.getenv("SUPABASE_KEY", "sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa"))
    supabase_service_role_key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

    # Server Configuration
    host: str = os.getenv("OCR_HOST", "0.0.0.0")
    port: int = int(os.getenv("OCR_PORT", "5055"))
    debug: bool = os.getenv("OCR_DEBUG", "false").lower() in ("true", "1", "yes")

    # Camera Image Quality Thresholds (Section 8)
    min_image_width: int = 600
    min_image_height: int = 600
    min_blur_score: float = 35.0          # Laplacian variance minimum
    min_brightness: float = 30.0          # Average pixel intensity minimum (too dark)
    max_brightness: float = 245.0         # Average pixel intensity maximum (washed out)

    # Resolution Normalization (Section 6)
    scale_min_width: int = 850
    scale_target_small: int = 1200
    scale_max_width: int = 2400
    scale_target_large: int = 2000

    # Multi-page PDF Settings (Section 5)
    pdf_render_scale: float = 2.0        # Default render scale (~144-200 DPI)
    max_pdf_pages: int = 25

    # Storage of raw tokens (Section 31)
    store_raw_tokens: bool = os.getenv("OCR_STORE_RAW_TOKENS", "true").lower() in ("true", "1")

config = OcrConfig()
