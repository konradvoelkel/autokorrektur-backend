# autokorrektur-backend

Optional cloud service for [AutoKorrektur](https://github.com/konradvoelkel/AutoKorrektur): SDXL inpainting
for clients that ask for photorealistic quality instead of the on-device MI-GAN result.

**Status: not in production, and not used by any published build.** The Android app's Play Store
flavor (`core`) has no internet permission at all; the cloud tier exists only behind the
`FEATURE_CLOUD_SDXL` flag in the `beta`/`full` flavors. This repository was split out of the app
repository on 2026-09-24 with its history.

Also here: `benchmark_ml.py`, the desktop evaluation harness that scores segmentation and
inpainting quality (IoU, Dice, Boundary-IoU, over-masking rate, PSNR/SSIM) over the 50-triple
ground-truth set and writes an HTML diff report.

## Run it

```bash
scripts/fetch_assets.sh            # test fixtures, verified by SHA-256 (see scripts/assets.manifest)
uv sync --extra dev
uv run pytest --cov=.
uv run uvicorn server:app --port 8000
uv run python benchmark_ml.py      # writes benchmark_report.html
```

`ruff check .` and `mypy .` (strict) are expected to stay clean.

## API

| Endpoint | Purpose |
|---|---|
| `GET /health` | `{"status": "ok", "redis_connected": …, "sdxl_loaded": …}` |
| `POST /v1/inpaint` | multipart: `device_uuid`, `play_integrity_token`, `image`, `mask`, optional `preview` → streamed `image/jpeg`, or `429` when the daily quota is spent |
| `GET /v1/nonce` | nonce for the Play Integrity check |

Images are processed in memory and re-encoded on the way out; nothing is written to disk. SDXL
inference is serialised behind an `asyncio.Semaphore(1)` so concurrent requests cannot exhaust GPU
memory, and requests are rate-limited per device **and** per client IP via Redis (in-memory
fallback). Preconditions are enforced at runtime with `icontract`.

## Configuration

Environment variables, prefixed `AUTOKORREKTUR_`: `REDIS_URL`, `MAX_DAILY_REQUESTS` (10),
`MAX_UPLOAD_BYTES` (10 MB), `ENABLE_SDXL_LOAD` (false), `STRICT_INTEGRITY_CHECK` (true),
`ALLOWED_INTEGRITY_TOKENS`, `GOOGLE_APPLICATION_CREDENTIALS`, `ANDROID_PACKAGE_NAME`.
Defaults live in `config.py` — that file is the reference, not this list.

## Deployment

German data centre for GDPR reasons (Hetzner Falkenstein/Nuremberg or AWS `eu-central-1`); a GPU
with 12 GB+ VRAM gives ~2–3 s per image, CPU-only ~15–20 s.

```bash
printf 'AUTOKORREKTUR_MAX_DAILY_REQUESTS=2\nREDIS_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
docker compose up -d --build
```

Compose refuses to start without `REDIS_PASSWORD` and does not publish the Redis port. Put a
reverse proxy with automatic TLS in front (Caddy: `api.example.org { reverse_proxy 127.0.0.1:8000 }`)
and check `curl -i https://<host>/health`.

If this ever goes live, the app's `BACKEND_URL` (release build type in `app/build.gradle.kts`), the
privacy policy and the Play Data Safety answers all have to be updated in the app repository first —
they currently state that the published app has no network access.
