import io
import base64
from typing import List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from PIL import Image
import numpy as np
from paddleocr import PaddleOCR

app = FastAPI(title="PaddleOCR Service for PingPay")

# Lazy load OCR engine or initialize with use_angle_cls=False to avoid paddlex orientation classifier bug
ocr_engine = None

def get_ocr():
    global ocr_engine
    if ocr_engine is None:
        print("[PaddleOCR] Initializing model with lang='th'...")
        ocr_engine = PaddleOCR(lang="th", use_angle_cls=False, show_log=False)
        print("[PaddleOCR] Model initialized successfully!")
    return ocr_engine

class OCRRequest(BaseModel):
    images: List[str]  # Base64 encoded images

@app.get("/")
def health_check():
    return {"status": "ok", "service": "PaddleOCR"}

@app.post("/predict/ocr_system")
async def predict_ocr(req: OCRRequest):
    if not req.images or len(req.images) == 0:
        raise HTTPException(status_code=400, detail="No images provided")

    ocr = get_ocr()
    all_results = []

    for b64_img in req.images:
        try:
            image_data = base64.b64decode(b64_img)
            image = Image.open(io.BytesIO(image_data)).convert("RGB")
            img_np = np.array(image)

            # Run inference
            result = ocr.ocr(img_np, cls=False)

            formatted_lines = []
            if result and len(result) > 0 and result[0] is not None:
                for line in result[0]:
                    formatted_lines.append(line)

            all_results.append(formatted_lines)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"OCR processing failed: {str(e)}")

    return {"results": all_results}
