import os
import json
import mimetypes
import time
import traceback

from fastapi import FastAPI, UploadFile, File, HTTPException
from google import genai
from google.genai import types


app = FastAPI(title="RecyConnect AI")


API_KEY = os.environ.get("GEMINI_API_KEY")

if not API_KEY:
    raise RuntimeError("GEMINI_API_KEY is not set.")

client = genai.Client(api_key=API_KEY)


@app.get("/")
def home():
    return {
        "status": "online",
        "service": "RecyConnect AI"
    }


@app.post("/analyze-ewaste")
async def analyze_ewaste(file: UploadFile = File(...)):

    # -----------------------------
    # Validate image
    # -----------------------------
    content_type = file.content_type

    if not content_type or not content_type.startswith("image/"):
        guessed_type, _ = mimetypes.guess_type(file.filename or "")

        if guessed_type and guessed_type.startswith("image/"):
            content_type = guessed_type
        else:
            raise HTTPException(
                status_code=400,
                detail="Please upload a valid image."
            )

    image_bytes = await file.read()

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Image is empty."
        )

    # -----------------------------
    # AI Prompt
    # -----------------------------
    prompt = """
You are an e-waste classification assistant for RecyConnect.

Analyze the uploaded e-waste image.

Choose ONLY ONE material from:

- PCB / Electronic Parts
- Mobile Phones
- Computers / Laptops
- Batteries
- Cables / Wires
- Other E-Waste

Return ONLY valid JSON in this exact structure:

{
  "material": "...",
  "confidence": 0.0,
  "condition": "...",
  "safety": "...",
  "observation": "..."
}

Rules:

- confidence must be between 0 and 1.
- Do not invent details that cannot reasonably be seen.
- If the image is unclear, use "Other E-Waste" and a lower confidence.
- For batteries or visibly damaged components, mention an appropriate safety warning.
- Keep observation short.
"""

    # -----------------------------
    # Gemini request with retry
    # -----------------------------
    max_attempts = 3

    for attempt in range(1, max_attempts + 1):

        try:

            print(f"🤖 Gemini attempt {attempt}/{max_attempts}")

            response = client.models.generate_content(
                model="gemini-3.1-flash-lite",
                contents=[
                    types.Part.from_bytes(
                        data=image_bytes,
                        mime_type=content_type,
                    ),
                    prompt,
                ],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    thinking_config=types.ThinkingConfig(
                        thinking_level="minimal"
                    ),
                ),
            )

            if not response.text:
                raise Exception("Gemini returned an empty response.")

            result = json.loads(response.text)

            print("✅ Gemini analysis successful")
            print(result)

            return result

        except Exception as e:

            error_text = str(e)

            print("🔥 GEMINI ERROR:")
            print(error_text)

            # Retry temporary Gemini/server errors
            if (
                "503" in error_text
                or "UNAVAILABLE" in error_text
                or "429" in error_text
                or "RESOURCE_EXHAUSTED" in error_text
                or "500" in error_text
            ):

                if attempt < max_attempts:
                    wait_time = attempt * 2

                    print(
                        f"⏳ Temporary Gemini error. "
                        f"Retrying in {wait_time} seconds..."
                    )

                    time.sleep(wait_time)
                    continue

            traceback.print_exc()

            raise HTTPException(
                status_code=500,
                detail=f"AI analysis failed: {error_text}"
            )

    raise HTTPException(
        status_code=500,
        detail="AI analysis failed after multiple attempts."
    )