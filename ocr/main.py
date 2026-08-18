import io
import os
import base64
from typing import List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from PIL import Image, ImageOps
import numpy as np
import easyocr

app = FastAPI(title="Optimized High-Accuracy Thai & English OCR Service for PingPay")

reader = None

def get_reader():
    global reader
    if reader is None:
        print("[OCR] Initializing EasyOCR Reader for Thai and English...")
        reader = easyocr.Reader(["th", "en"], gpu=False, verbose=False)
        # Warmup with tiny dummy image
        dummy = np.zeros((64, 64, 3), dtype=np.uint8)
        reader.readtext(dummy)
        print("[OCR] EasyOCR Reader initialized!")
    return reader

@app.on_event("startup")
def startup_event():
    get_reader()

class OCRRequest(BaseModel):
    images: List[str]

@app.get("/")
def health_check():
    return {"status": "ok", "service": "Optimized-OCR"}

def run_optimized_ocr(image: Image.Image):
    image = ImageOps.exif_transpose(image)
    img_np = np.array(image)
    ocr_reader = get_reader()
    
    # Run EasyOCR with natural receipt detection
    results = ocr_reader.readtext(img_np, detail=1)

    items = []
    for (bbox, text, conf) in results:
        y_center = sum([pt[1] for pt in bbox]) / 4.0
        h_box = max([pt[1] for pt in bbox]) - min([pt[1] for pt in bbox])
        x_min = min([pt[0] for pt in bbox])
        box_coords = [[int(pt[0]), int(pt[1])] for pt in bbox]
        items.append({
            "bbox": box_coords,
            "text": text.strip(),
            "conf": float(conf),
            "y": y_center,
            "h": h_box,
            "x": x_min
        })

    items.sort(key=lambda item: item["y"])
    grouped_lines = []
    curr_line = []
    curr_y = None

    for item in items:
        dynamic_thresh = max(6, min(item["h"] * 0.45, 14))
        if curr_y is None:
            curr_line = [item]
            curr_y = item["y"]
        elif abs(item["y"] - curr_y) <= dynamic_thresh:
            curr_line.append(item)
            curr_y = sum([it["y"] for it in curr_line]) / len(curr_line)
        else:
            curr_line.sort(key=lambda it: it["x"])
            merged_text = " ".join([it["text"] for it in curr_line if it["text"]])
            if merged_text:
                grouped_lines.append([curr_line[0]["bbox"], [merged_text, curr_line[0]["conf"]]])
            curr_line = [item]
            curr_y = item["y"]

    if curr_line:
        curr_line.sort(key=lambda it: it["x"])
        merged_text = " ".join([it["text"] for it in curr_line if it["text"]])
        if merged_text:
            grouped_lines.append([curr_line[0]["bbox"], [merged_text, curr_line[0]["conf"]]])

    return grouped_lines

@app.post("/predict/ocr_system")
async def predict_ocr(req: OCRRequest):
    if not req.images or len(req.images) == 0:
        raise HTTPException(status_code=400, detail="No images provided")

    all_results = []
    for b64_img in req.images:
        try:
            image_data = base64.b64decode(b64_img)
            image = Image.open(io.BytesIO(image_data)).convert("RGB")
            formatted_lines = run_optimized_ocr(image)
            all_results.append(formatted_lines)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"OCR processing failed: {str(e)}")

    return {"results": all_results}
