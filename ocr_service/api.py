import os
import time
from typing import List, Optional
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import config
from engine import get_ocr_engine
from worker import ocr_worker, OcrJobState

app = FastAPI(
    title="Benchmark MMS Production OCR Service",
    description="High-accuracy PP-OCRv3 async invoice extraction engine with Supabase Material Master integration",
    version="2.0.0"
)

# Enable CORS for Flutter web / local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    # Warm up OCR engine singleton on server launch
    engine, err = get_ocr_engine()
    if err:
        print(f"Warning: OCR engine warmup error: {err}")
    else:
        print("RapidOCR PP-OCRv3 engine loaded and ready.")

@app.get("/api/ocr/health")
def health_check():
    engine, err = get_ocr_engine()
    return {
        "status": "healthy" if engine is not None else "degraded",
        "engine_ready": engine is not None,
        "model": "PP-OCRv3",
        "device": "CPU",
        "error": err
    }

@app.post("/api/ocr/jobs")
async def create_ocr_job(file: UploadFile = File(...)):
    """Async upload endpoint (Section 4).
    Creates an OCR job and queues it for background worker processing."""
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")

        job = ocr_worker.create_job(document_type="invoice")
        ocr_worker.submit_file_processing(job.job_id, content, file.filename or "upload.png")

        return {
            "job_id": job.job_id,
            "status": job.state,
            "progress_message": job.progress_message,
            "created_at": job.created_at
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to submit OCR job: {e}")

@app.get("/api/ocr/jobs/{job_id}")
def get_ocr_job_status(job_id: str):
    """Poll job status or fetch structured result once completed."""
    job = ocr_worker.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="OCR job not found.")

    response = {
        "job_id": job.job_id,
        "status": job.state,
        "progress_message": job.progress_message,
        "progress_percent": round(job.progress_percent, 2),
        "pages_processed": job.pages_processed,
        "total_pages": job.total_pages,
        "created_at": job.created_at,
        "completed_at": job.completed_at,
    }

    if job.state in (OcrJobState.COMPLETED, OcrJobState.REVIEW_REQUIRED):
        response["result"] = job.result
    elif job.state == OcrJobState.FAILED:
        response["error"] = job.error

    return response

@app.post("/api/ocr/multipage")
async def create_multipage_ocr_job(files: List[UploadFile] = File(...)):
    """Async multi-page OCR job creation (Section 30).
    Captures Page 1, Page 2, ... N and processes them into ONE unified invoice."""
    try:
        if not files:
            raise HTTPException(status_code=400, detail="No files uploaded.")

        files_data = []
        for f in files:
            content = await f.read()
            if content:
                files_data.append((f.filename or "page.png", content))

        if not files_data:
            raise HTTPException(status_code=400, detail="All uploaded files were empty.")

        job = ocr_worker.create_job(document_type="multi_page_invoice")
        ocr_worker.submit_multipage_processing(job.job_id, files_data)

        return {
            "job_id": job.job_id,
            "status": job.state,
            "document_type": "multi_page_invoice",
            "pages_submitted": len(files_data),
            "progress_message": job.progress_message
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to submit multi-page job: {e}")

@app.post("/api/ocr/parse")
async def parse_synchronous(file: UploadFile = File(...)):
    """Direct synchronous endpoint for testing or immediate responses."""
    try:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")

        job = ocr_worker.create_job(document_type="invoice")
        # Run directly in thread
        ocr_worker._process_file_job(job.job_id, content, file.filename or "upload.png")

        if job.state == OcrJobState.FAILED:
            raise HTTPException(status_code=500, detail=job.error or "OCR processing failed.")

        return job.result or {"success": False, "error": "No result generated."}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api:app", host=config.host, port=config.port, reload=config.debug)
