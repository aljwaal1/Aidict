import io
import os
from unittest.mock import patch

from fastapi.testclient import TestClient
from PIL import Image

from app import app


def test_authentication_and_text_input():
    with patch.dict(os.environ, {"AIDICT_ACCESS_TOKEN": "test-secret"}):
        client = TestClient(app)
        response = client.post("/v1/aidict", json={"task": "summarize", "text": "hello"})
        assert response.status_code == 401
        response = client.post("/v1/aidict", headers={"Authorization": "Bearer test-secret"},
                               json={"task": "unsupported", "text": "hello"})
        assert response.status_code == 400


def test_oversized_json():
    client = TestClient(app)
    response = client.post("/v1/aidict", data=b"x" * 65537,
                           headers={"Content-Type": "application/json"})
    assert response.status_code == 413


def test_missing_audio_file_and_unknown_task():
    client = TestClient(app)
    response = client.post("/v1/aidict", data={"task": "transcribe"})
    assert response.status_code == 400
    response = client.post("/v1/aidict", data={"task": "unknown"})
    assert response.status_code == 400


def test_ocr_image_path_uses_tesseract():
    image = Image.new("RGB", (20, 20), "white")
    data = io.BytesIO()
    image.save(data, format="PNG")
    with patch("app.pytesseract.image_to_string", return_value="مرحبا"):
        client = TestClient(app)
        response = client.post("/v1/aidict", data={"task": "ocr"},
                               files={"image": ("test.png", data.getvalue(), "image/png")})
    assert response.status_code == 200
    assert response.json() == {"result": "مرحبا"}
