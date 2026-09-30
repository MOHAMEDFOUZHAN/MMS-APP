@echo off
title Benchmark MMS OCR Production Service
echo ======================================================================
echo  STARTING BENCHMARK MMS PRODUCTION OCR ENGINE
echo  Model: RapidOCR PP-OCRv3 (ONNX Runtime CPU)
echo  Port: 5055
echo ======================================================================

cd /d "%~dp0"
python -m uvicorn api:app --host 0.0.0.0 --port 5055
pause
