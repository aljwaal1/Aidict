# Optional free self-hosted backend for Aidict

This backend replaces *paid APIs*, not the Android offline engine. It runs on a user's own Linux/desktop server; running it incurs electricity/compute and possibly hosting costs. Nothing is deployed automatically.

Dependencies: Python 3.11+, FastAPI, Uvicorn, python-multipart, Pillow, pytesseract, faster-whisper; system Tesseract OCR binary + `ara` and `eng` traineddata. Generative writing needs an optional local Ollama server and an installed licensed model.

Install:
```bash
sudo apt-get install tesseract-ocr tesseract-ocr-ara tesseract-ocr-eng
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
export AIDICT_ACCESS_TOKEN='replace-with-a-strong-secret'
uvicorn app:app --host 127.0.0.1 --port 8765
```
Expose over HTTPS through your own authenticated reverse proxy. The Android app currently does **not** send bearer tokens; if you use a shared-secret proxy, configure the proxy to authenticate independently or extend the client and store tokens securely. Do not expose an unauthenticated service publicly.

Endpoints match the mobile `AiBackend` contract: POST /v1/aidict multipart `task=ocr,image=` or `task=transcribe,audio=`; JSON `task=rewrite|proofread|summarize,text,language`. All successful responses: `{"result":"..."}`.

**Privacy and production limits**: uploaded audio/images/text can be personal information. The server must impose upload size limits at its reverse proxy, rate limiting, authentication, consent, retention controls and TLS. This reference implementation includes only baseline content-size checks and an optional bearer-token check, so it is **not production-ready**. Audio transcription needs CPU/GPU and Whisper model download; Tesseract Arabic OCR accuracy varies. Ollama requires a running model. Models have their own licenses.

For Android integration, the app's optional endpoint can be `https://your-domain.example/v1/aidict`. Note that text-format summarization already has a separate no-server offline extraction option in Flutter.
