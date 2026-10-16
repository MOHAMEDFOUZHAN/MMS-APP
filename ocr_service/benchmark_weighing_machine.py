"""
Benchmark MMS - Weighing Machine LED OCR Evaluation Suite
Benchmarks PaddleOCR PP-OCRv5 (RapidOCR ONNX Engine) and 7-Segment Fallback
Tests 15 distinct industrial display scenarios matching Baykon BX27 specifications.
"""

import time
import cv2
import numpy as np
from weighing_machine_ocr import process_weighing_machine_image

def generate_test_indicator_image(
    text: str,
    width: int = 550,
    height: int = 150,
    blur: bool = False,
    glare: bool = False,
    dim: bool = False,
    red_led: bool = True
) -> bytes:
    """Generate synthetic weighing indicator photo simulating Baykon BX27 red 7-segment display."""
    img = np.zeros((height, width, 3), dtype=np.uint8)
    # Dark indicator bezel / casing
    img[:] = (15, 12, 10)

    # Display window / glass filter (dark red tint)
    cv2.rectangle(img, (20, 15), (width - 20, height - 15), (30, 8, 8), -1)
    cv2.rectangle(img, (20, 15), (width - 20, height - 15), (60, 30, 30), 2)

    # Digit color (bright red LED or dim red)
    color = (20, 15, 250) if red_led else (20, 240, 20)
    if dim:
        color = (10, 8, 110)

    # Draw LED text
    font_scale = 2.4
    thickness = 4
    cv2.putText(img, text, (45, int(height * 0.68)), cv2.FONT_HERSHEY_PLAIN, font_scale, color, thickness)

    # Glare / camera reflection simulation
    if glare:
        cv2.circle(img, (int(width * 0.45), int(height * 0.5)), 50, (180, 180, 220), -1)

    # Blur simulation
    if blur:
        img = cv2.GaussianBlur(img, (21, 21), 0)

    _, buf = cv2.imencode('.png', img)
    return buf.tobytes()


def run_benchmark():
    print("=" * 70)
    print(" BENCHMARK MMS: INDUSTRIAL WEIGHING MACHINE OCR BENCHMARK")
    print(" Model: PaddleOCR PP-OCRv5 (RapidOCR ONNX Engine) + 7-Segment Fallback")
    print("=" * 70)

    test_cases = [
        # (Label, Expected Weight, Expected Unit, Expected Valid, Gen Args)
        ("Standard 12.450 kg (Standard Baykon BX27)", 12.450, "KG", True, {"text": "12.450 kg"}),
        ("Whole number 24 kg (Strict Integer - NEVER 4.240)", 24.0, "KG", True, {"text": "24 kg"}),
        ("Whole number 12 kg (Strict Integer)", 12.0, "KG", True, {"text": "12 kg"}),
        ("Whole number 125 kg (Strict Integer)", 125.0, "KG", True, {"text": "125 kg"}),
        ("Standard 1250 g (Grams format)", 1250.0, "G", True, {"text": "1250 g"}),
        ("Standard 0.850 kg (Sub-kilogram chocolate slab)", 0.850, "KG", True, {"text": "0.850 kg"}),
        ("Standard 25.000 kg (Full bulk batch)", 25.000, "KG", True, {"text": "25.000 kg"}),
        ("Standard 5.500 kg (Intermediate batch)", 5.500, "KG", True, {"text": "5.500 kg"}),
        ("Single digit decimal 1.5 kg", 1.5, "KG", True, {"text": "1.5 kg"}),
        ("Two decimals 4.75 kg", 4.75, "KG", True, {"text": "4.75 kg"}),
        ("Dim lighting 12.450 kg", 12.450, "KG", True, {"text": "12.450 kg", "dim": True}),
        ("Camera reflection / glare 12.450 kg", 12.450, "KG", True, {"text": "12.450 kg", "glare": True}),
        ("Green LED variant 10.200 kg", 10.200, "KG", True, {"text": "10.200 kg", "red_led": False}),
        ("Zero weight indicator 0.000 kg (Scale empty)", None, "KG", False, {"text": "0.000 kg"}),
        ("Overload error state 'OL kg' (Baykon Error)", None, "KG", False, {"text": "OL kg"}),
        ("Internal error state 'Err 2' (Indicator Error)", None, "KG", False, {"text": "Err 2"}),
        ("Severely blurred camera frame (Unusable)", None, "KG", False, {"text": "12.450 kg", "blur": True}),
        ("Blank / unlit display (Display Off)", None, "KG", False, {"text": "    "}),
    ]

    total_tests = len(test_cases)
    exact_weight_correct = 0
    decimal_correct = 0
    unit_correct = 0
    validity_correct = 0
    false_accepts = 0
    latencies = []

    print(f"\nRunning {total_tests} comprehensive test scenarios...\n")

    for idx, (label, exp_weight, exp_unit, exp_valid, kwargs) in enumerate(test_cases, 1):
        img_bytes = generate_test_indicator_image(**kwargs)
        res = process_weighing_machine_image(img_bytes)

        latencies.append(res.get("processing_time_ms", 0))

        actual_valid = res.get("success", False)
        actual_weight = res.get("numeric_weight")
        actual_unit = res.get("unit")

        # 1. Validity judgment correctness
        is_val_ok = (actual_valid == exp_valid)
        if is_val_ok:
            validity_correct += 1
        elif actual_valid and not exp_valid:
            false_accepts += 1

        # 2. Accuracy on valid tests
        is_wt_ok = False
        is_dec_ok = False
        is_un_ok = False

        if exp_valid and actual_valid and actual_weight is not None:
            # Check within 0.001 tolerance
            is_wt_ok = abs(actual_weight - exp_weight) < 0.002
            # Check decimal precision
            exp_has_dec = (exp_weight % 1.0 != 0.0)
            act_has_dec = (actual_weight % 1.0 != 0.0)
            is_dec_ok = (exp_has_dec == act_has_dec)
            is_un_ok = (actual_unit == exp_unit)

            if is_wt_ok:
                exact_weight_correct += 1
            if is_dec_ok:
                decimal_correct += 1
            if is_un_ok:
                unit_correct += 1

        status_sym = "[PASS]" if (is_val_ok and (not exp_valid or is_wt_ok)) else "[FAIL]"
        readout = f"{actual_weight} {actual_unit}" if actual_weight is not None else (res.get("error") or "REJECTED")
        print(f" {status_sym} #{idx:02d} {label}")
        print(f"       Expected: {exp_weight} {exp_unit} (Valid: {exp_valid}) | Detected: {readout} ({res.get('processing_time_ms', 0)}ms)")

    # Aggregate Metrics
    valid_scenarios_count = sum(1 for _, _, _, exp_valid, _ in test_cases if exp_valid)
    invalid_scenarios_count = total_tests - valid_scenarios_count

    weight_accuracy_pct = (exact_weight_correct / valid_scenarios_count) * 100.0
    decimal_accuracy_pct = (decimal_correct / valid_scenarios_count) * 100.0
    unit_accuracy_pct = (unit_correct / valid_scenarios_count) * 100.0
    validity_decision_pct = (validity_correct / total_tests) * 100.0
    avg_latency = float(np.mean(latencies))

    print("\n" + "=" * 70)
    print(" BENCHMARK ACCURACY & EVALUATION REPORT")
    print("=" * 70)
    print(f" Exact Weight Reading Accuracy:   {weight_accuracy_pct:.1f}% ({exact_weight_correct}/{valid_scenarios_count})")
    print(f" Decimal Point Accuracy:          {decimal_accuracy_pct:.1f}% ({decimal_correct}/{valid_scenarios_count})")
    print(f" Unit Recognition Accuracy:       {unit_accuracy_pct:.1f}% ({unit_correct}/{valid_scenarios_count})")
    print(f" Invalid/Error Rejection Rate:    {((invalid_scenarios_count - false_accepts)/invalid_scenarios_count)*100.0:.1f}%")
    print(f" False Acceptance Rate (FAR):     {(false_accepts / invalid_scenarios_count) * 100.0:.1f}%")
    print(f" Average Processing Time:         {avg_latency:.1f} ms")
    print("=" * 70)

if __name__ == "__main__":
    run_benchmark()
