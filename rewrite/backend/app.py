import io
import hmac
import os
from functools import lru_cache

import httpx
import pytesseract
from fastapi import FastAPI, Header, HTTPException, Request
from starlette.datastructures import UploadFile
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field

app = FastAPI(title="Aidict Self-Hosted Processing API", docs_url=None, redoc_url=None)
MAX_FILE_BYTES = 12 * 1024 * 1024
MAX_TEXT_CHARS = 12000


class TextTask(BaseModel):
    task: str
    text: str = Field(min_length=1, max_length=MAX_TEXT_CHARS)
    language: str = "ar"


def check_token(value: str | None) -> None:
    configured = os.environ.get("AIDICT_ACCESS_TOKEN")
    if configured and not hmac.compare_digest(value or "", f"Bearer {configured}"):
        raise HTTPException(status_code=401, detail="Unauthorized")


async def load_upload(file: UploadFile) -> bytes:
    result = await file.read(MAX_FILE_BYTES + 1)
    if len(result) > MAX_FILE_BYTES:
        raise HTTPException(status_code=413, detail="Upload exceeds 12 MiB")
    if not result:
        raise HTTPException(status_code=400, detail="Empty upload")
    return result


@lru_cache(maxsize=1)
def whisper_model():
    from faster_whisper import WhisperModel
    model_name = os.environ.get("AIDICT_WHISPER_MODEL", "small")
    return WhisperModel(model_name, device="cpu", compute_type="int8")


async def process_text(data: TextTask) -> dict[str, str]:
    if data.task not in {"rewrite", "proofread", "summarize"}:
        raise HTTPException(status_code=400, detail="Unsupported task")
    model = os.environ.get("AIDICT_OLLAMA_MODEL")
    if not model:
        raise HTTPException(status_code=503, detail="Configure AIDICT_OLLAMA_MODEL first")
    instructions = {
        "rewrite": "Rewrite clearly while preserving meaning.",
        "proofread": "Correct grammar and spelling without changing meaning.",
        "summarize": "Summarize accurately without inventing facts.",
    }
    url = os.environ.get("AIDICT_OLLAMA_URL", "http://127.0.0.1:11434")
    prompt = f"{instructions[data.task]} Answer in {data.language}.\n\n{data.text}"
    try:
        async with httpx.AsyncClient(timeout=100) as client:
            response = await client.post(f"{url.rstrip('/')}/api/generate",
                json={"model": model, "prompt": prompt, "stream": False})
            response.raise_for_status()
            result = response.json().get("response", "").strip()
    except (httpx.HTTPError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise HTTPException(status_code=502, detail="Local AI service unavailable") from exc
    if not result:
        raise HTTPException(status_code=502, detail="Empty AI response")
    return {"result": result}


@app.post("/v1/aidict")
async def aidict(
    request: Request,
    authorization: str | None = Header(default=None),
):
    check_token(authorization)
    media_type = request.headers.get("content-type", "").lower()
    if media_type.startswith("application/json"):
        try:
            payload = TextTask.model_validate(await request.json())
        except Exception as exc:
            raise HTTPException(status_code=422, detail="Invalid text payload") from exc
        return await process_text(payload)
    if not media_type.startswith("multipart/form-data"):
        raise HTTPException(status_code=415, detail="Expected JSON or multipart")
    # Reject oversized requests before multipart decoding; enforce a proxy body
    # limit as well because a client can omit Content-Length.
    length = request.headers.get('content-length')
    if length is not None:
        try:
            if int(length) > MAX_FILE_BYTES + 65536:
                raise HTTPException(status_code=413, detail='Request too large')
        except ValueError as exc:
            raise HTTPException(status_code=400, detail='Invalid Content-Length') from exc
    form = await request.form(max_files=1, max_fields=3, max_part_size=MAX_FILE_BYTES)
    task = str(form.get("task", ""))
    if task == "ocr":
        uploaded = form.get("image")
        if not isinstance(uploaded, UploadFile):
            raise HTTPException(status_code=400, detail="Missing image")
        raw = await load_upload(uploaded)
        try:
            image = Image.open(io.BytesIO(raw))
            image.verify()
            image = Image.open(io.BytesIO(raw))
            if image.width * image.height > 30_000_000:
                raise HTTPException(status_code=413, detail="Image too large")
            text = pytesseract.image_to_string(image.convert("RGB"), lang="ara+eng")
        except (UnidentifiedImageError, Image.DecompressionBombError, OSError, ValueError) as exc:
            raise HTTPException(status_code=400, detail="Invalid image") from exc
    elif task == "transcribe":
        uploaded = form.get("audio")
        if not isinstance(uploaded, UploadFile):
            raise HTTPException(status_code=400, detail="Missing audio")
        raw = await load_upload(uploaded)
        import tempfile
        from pathlib import Path
        suffix = Path(uploaded.filename or "").suffix.lower()
        if suffix not in {".mp3", ".wav", ".m4a", ".aac", ".ogg", ".flac"}:
            raise HTTPException(status_code=400, detail="Unsupported audio format")
        with tempfile.NamedTemporaryFile(suffix=suffix) as tmp:
            tmp.write(raw)
            tmp.flush()
            try:
                segments, _ = whisper_model().transcribe(tmp.name, beam_size=3)
                text = " ".join(s.text.strip() for s in segments)
            except Exception as exc:
                raise HTTPException(status_code=502, detail="Transcription engine failed") from exc
    else:
        raise HTTPException(status_code=400, detail="Unsupported multipart task")
    text = text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="No text detected")
    return {"result": text}
