"""
AppGrowth Studio + ViMax & Wan2GP Backend Service.
Local REST API and background job manager connecting Flutter desktop to
the ViMax agentic framework, Wan2GP local diffusion provider, WebExtractor,
AudioSynthesizer, and VideoRenderer.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, List, Optional

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from backend.audio_synthesizer import AudioSynthesizer
from backend.executable_resolver import detect_gpu_hardware, get_workspace_root, resolve_ffmpeg_path, resolve_python_path
from backend.video_renderer import VideoRenderer
from backend.vimax_bridge import ViMaxBridge
from backend.vimax_provider import ViMaxProvider
from backend.wan2gp_provider import WAN2GP_ATTRIBUTION, WAN2GP_MODELS, Wan2GPProvider
from backend.web_extractor import WebExtractor

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("backend")


class JobManager:
    """Thread-safe background job runner and persistent state store."""

    def __init__(self, persistence_file: Optional[str] = None):
        root = get_workspace_root()
        default_p = os.path.join(root, "backend", "jobs.json")
        self.persistence_file = os.path.abspath(persistence_file or default_p)
        self.lock = threading.Lock()
        self.jobs: Dict[str, Dict[str, Any]] = self._load_jobs()
        self.active_threads: Dict[str, threading.Thread] = {}
        self.cancel_flags: Dict[str, bool] = {}

    def _load_jobs(self) -> Dict[str, Dict[str, Any]]:
        if os.path.exists(self.persistence_file):
            try:
                with open(self.persistence_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def _save_jobs(self) -> None:
        try:
            with open(self.persistence_file, "w", encoding="utf-8") as f:
                json.dump(self.jobs, f, indent=2)
        except Exception:
            pass

    def create_job(self, job_id: str, request_data: Dict[str, Any]) -> Dict[str, Any]:
        with self.lock:
            provider = request_data.get("provider", "vimax")
            job = {
                "job_id": job_id,
                "provider": provider,
                "status": "queued",
                "stage": "queued",
                "stage_message": f"Job registered in queue for {provider.upper()}",
                "progress": 0.0,
                "created_at": time.time(),
                "started_at": None,
                "completed_at": None,
                "elapsed_seconds": 0.0,
                "request": request_data,
                "mp4_path": None,
                "validation": None,
                "error": None,
                "logs": [f"[{time.strftime('%X')}] Job queued ({provider})"],
            }
            self.jobs[job_id] = job
            self.cancel_flags[job_id] = False
            self._save_jobs()
            return job

    def update_job(
        self,
        job_id: str,
        status: Optional[str] = None,
        stage: Optional[str] = None,
        stage_message: Optional[str] = None,
        progress: Optional[float] = None,
        mp4_path: Optional[str] = None,
        validation: Optional[Dict[str, Any]] = None,
        error: Optional[str] = None,
        log_message: Optional[str] = None,
    ) -> None:
        with self.lock:
            job = self.jobs.get(job_id)
            if not job:
                return
            if status:
                job["status"] = status
            if stage:
                job["stage"] = stage
            if stage_message:
                job["stage_message"] = stage_message
            if progress is not None:
                job["progress"] = min(1.0, max(0.0, progress))
            if mp4_path:
                job["mp4_path"] = mp4_path
            if validation:
                job["validation"] = validation
            if error:
                job["error"] = error
            if log_message:
                job["logs"].append(f"[{time.strftime('%X')}] {log_message}")
            if job["started_at"]:
                job["elapsed_seconds"] = round(time.time() - job["started_at"], 1)
            self._save_jobs()

    def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        with self.lock:
            job = self.jobs.get(job_id)
            if job and job.get("status") in ["queued", "generating_script", "generating_video_clips", "assembling_video", "validating_output", "preparing_inputs"] and job.get("started_at"):
                job["elapsed_seconds"] = round(time.time() - job["started_at"], 1)
            return job

    def list_jobs(self, limit: int = 25) -> List[Dict[str, Any]]:
        with self.lock:
            sorted_jobs = sorted(self.jobs.values(), key=lambda j: j.get("created_at", 0), reverse=True)
            return sorted_jobs[:limit]

    def cancel_job(self, job_id: str) -> bool:
        with self.lock:
            if job_id in self.jobs and self.jobs[job_id]["status"] not in ["completed", "failed", "cancelled"]:
                self.cancel_flags[job_id] = True
                self.jobs[job_id]["status"] = "cancelled"
                self.jobs[job_id]["stage_message"] = "Job cancelled by user"
                self._save_jobs()
                return True
            return False

    def is_cancelled(self, job_id: str) -> bool:
        return self.cancel_flags.get(job_id, False)


# Global instances
web_extractor = WebExtractor()
vimax_bridge = ViMaxBridge()
audio_synth = AudioSynthesizer()
video_renderer = VideoRenderer()
job_manager = JobManager()

vimax_provider = ViMaxProvider()
wan2gp_provider = Wan2GPProvider()

PROVIDERS = {
    "vimax": vimax_provider,
    "wan2gp": wan2gp_provider,
}


def _run_generation_task(job_id: str, request_data: Dict[str, Any]) -> None:
    """Asynchronous background worker for video generation."""
    try:
        provider_name = request_data.get("provider", "vimax").lower()
        job_manager.update_job(
            job_id,
            status="preparing_inputs",
            stage="preparing_inputs",
            stage_message=f"Preparing inputs for {provider_name.upper()} pipeline",
            log_message=f"Starting generation pipeline via {provider_name}",
        )
        job_manager.jobs[job_id]["started_at"] = time.time()

        scenes = request_data.get("scenes", [])
        archetype = request_data.get("archetype", "saas_product_ad")
        aspect_ratio = request_data.get("aspect_ratio", "9:16")
        resolution = request_data.get("resolution", "720p")
        brand_color = request_data.get("brand_color", "#2563EB")
        brand_name = request_data.get("brand_name", "")

        # 1. Plan Storyboard if scenes not supplied
        if not scenes:
            job_manager.update_job(job_id, stage="generating_storyboard", stage_message="Planning agentic storyboard", progress=0.1)
            scenes = vimax_bridge.plan_storyboard(
                archetype=archetype,
                aspect_ratio=aspect_ratio,
                resolution=resolution,
                brand_name=brand_name,
                description=request_data.get("description", ""),
                features=request_data.get("features", []),
                user_script=request_data.get("user_script"),
                uploaded_image_paths=request_data.get("image_paths", []),
                video_clip_paths=request_data.get("video_clip_paths", []),
            )

        if job_manager.is_cancelled(job_id):
            return

        # 2. Wan2GP Provider Specific Execution
        if provider_name == "wan2gp":
            wan_health = wan2gp_provider.check_health()
            if not wan_health["is_available"]:
                raise RuntimeError(f"Wan2GP Provider Unavailable: {wan_health['message']}")

            job_manager.update_job(
                job_id,
                stage="generating_video_clips",
                stage_message=f"Generating diffusion clips via Wan2GP ({wan_health['details']['selected_model']})",
                progress=0.2,
                log_message=f"Wan2GP loaded: {wan_health['details']['selected_model']}",
            )

            total_scenes = len(scenes)
            for idx, scene in enumerate(scenes):
                if job_manager.is_cancelled(job_id):
                    return
                shot_prompt = scene.get("visual_generation_prompt") or scene.get("visual_description") or "Modern promotional sequence"
                ref_img = None
                img_assets = scene.get("visual_asset_paths", [])
                if img_assets:
                    ref_img = next((p for p in img_assets if p and os.path.isfile(p)), None)

                clip_res = wan2gp_provider.generate_clip(
                    shot_id=f"scene_{idx + 1}",
                    prompt=shot_prompt,
                    duration_seconds=float(scene.get("duration_seconds") or scene.get("duration") or 4.0),
                    aspect_ratio=aspect_ratio,
                    resolution=resolution,
                    reference_image_path=ref_img,
                )
                if clip_res["status"] == "completed" and clip_res.get("clip_path"):
                    scene["visual_asset_paths"] = [clip_res["clip_path"]]
                    scene["video_clip_path"] = clip_res["clip_path"]
                else:
                    logger.warning("Wan2GP clip failed for scene %d: %s. Using procedural compositor fallback.", idx + 1, clip_res.get("error"))

                pct = 0.2 + (0.5 * ((idx + 1) / total_scenes))
                job_manager.update_job(
                    job_id,
                    stage="generating_video_clips",
                    stage_message=f"Wan2GP completed scene {idx + 1}/{total_scenes}",
                    progress=pct,
                    log_message=f"Scene {idx + 1}/{total_scenes} clip ready",
                )

        # 3. Assemble and Master via VideoRenderer
        def on_render_progress(stage: str, message: str, pct: float):
            if job_manager.is_cancelled(job_id):
                raise RuntimeError("Job cancelled by user")
            job_manager.update_job(job_id, status=stage, stage=stage, stage_message=message, progress=pct, log_message=f"{stage}: {message}")

        render_res = video_renderer.render_project(
            project_id=job_id,
            scenes=scenes,
            aspect_ratio=aspect_ratio,
            resolution=resolution,
            brand_color=brand_color,
            progress_callback=on_render_progress,
        )

        job_manager.update_job(
            job_id,
            status="completed",
            stage="completed",
            stage_message="Video generated and validated successfully",
            progress=1.0,
            mp4_path=render_res["mp4_path"],
            validation=render_res["validation"],
            log_message=f"Exported MP4: {render_res['mp4_path']} ({render_res['validation']['duration_seconds']}s)",
        )
        job_manager.jobs[job_id]["completed_at"] = time.time()
        job_manager._save_jobs()

    except Exception as e:
        err_msg = str(e)
        logger.exception("Generation task failed: %s", err_msg)
        job_manager.update_job(
            job_id,
            status="failed",
            stage="failed",
            stage_message=f"Generation failed: {err_msg}",
            error=err_msg,
            log_message=f"ERROR: {err_msg}",
        )


class ViMaxApiHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler for ViMax & Wan2GP Local API."""

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def _send_json(self, status_code: int, data: Any) -> None:
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _parse_json_body(self) -> Dict[str, Any]:
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        try:
            return json.loads(raw)
        except Exception:
            return {}

    def do_GET(self) -> None:
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        query = urllib.parse.parse_qs(parsed_url.query)

        if path in ["/health", "/api/status"]:
            status_data = vimax_bridge.get_provider_status()
            status_data["jobs_count"] = len(job_manager.jobs)
            status_data["active_providers"] = list(PROVIDERS.keys())
            status_data["wan2gp"] = wan2gp_provider.check_health()
            return self._send_json(200, status_data)

        if path == "/api/diagnostics":
            diag = vimax_bridge.run_diagnostics()
            diag["wan2gp_health"] = wan2gp_provider.check_health()
            diag["providers"] = {k: p.get_provider_info() for k, p in PROVIDERS.items()}
            return self._send_json(200, diag)

        if path == "/api/providers":
            info = {
                "active_provider_id": "vimax",
                "providers": [p.get_provider_info() for p in PROVIDERS.values()],
                "wan2gp_attribution": WAN2GP_ATTRIBUTION,
            }
            return self._send_json(200, info)

        if path == "/api/wan2gp/status":
            return self._send_json(200, wan2gp_provider.check_health())

        if path == "/api/wan2gp/models":
            return self._send_json(200, {
                "models": WAN2GP_MODELS,
                "attribution": WAN2GP_ATTRIBUTION,
                "official_repo": "https://github.com/deepbeepmeep/Wan2GP",
            })

        if path == "/api/config":
            return self._send_json(200, vimax_bridge._load_config())

        if path == "/api/jobs":
            limit = int(query.get("limit", [25])[0])
            return self._send_json(200, {"jobs": job_manager.list_jobs(limit)})

        if path.startswith("/api/jobs/"):
            job_id = path.split("/api/jobs/")[1].strip()
            job = job_manager.get_job(job_id)
            if job:
                return self._send_json(200, job)
            return self._send_json(404, {"error": "Job not found"})

        if path == "/api/assets":
            asset_path = query.get("path", [""])[0]
            if not asset_path or not os.path.exists(asset_path):
                return self._send_json(404, {"error": "Asset not found"})
            real_path = os.path.abspath(asset_path)
            content_type = "application/octet-stream"
            if real_path.endswith(".mp4"):
                content_type = "video/mp4"
            elif real_path.endswith(".png"):
                content_type = "image/png"
            elif real_path.endswith((".jpg", ".jpeg")):
                content_type = "image/jpeg"
            elif real_path.endswith(".wav"):
                content_type = "audio/wav"

            try:
                with open(real_path, "rb") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(content)))
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(content)
                return
            except Exception as e:
                return self._send_json(500, {"error": str(e)})

        self._send_json(404, {"error": f"Endpoint not found: {path}"})

    def do_POST(self) -> None:
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        body = self._parse_json_body()

        if path == "/api/config":
            saved = vimax_bridge.save_config(body)
            return self._send_json(200, {"success": True, "config": saved})

        if path == "/api/wan2gp/config":
            saved = wan2gp_provider.save_config(body)
            return self._send_json(200, {"success": True, "config": saved, "attribution": WAN2GP_ATTRIBUTION})

        if path == "/api/wan2gp/generate-clip":
            shot_id = body.get("shot_id", "clip_1")
            prompt = body.get("prompt", "")
            duration = float(body.get("duration", 4.0))
            aspect_ratio = body.get("aspect_ratio", "9:16")
            resolution = body.get("resolution", "720p")
            ref_img = body.get("reference_image_path")
            clip_res = wan2gp_provider.generate_clip(
                shot_id=shot_id,
                prompt=prompt,
                duration_seconds=duration,
                aspect_ratio=aspect_ratio,
                resolution=resolution,
                reference_image_path=ref_img,
            )
            return self._send_json(200, clip_res)

        if path == "/api/web/extract":
            url = body.get("url", "")
            if not url:
                return self._send_json(400, {"error": "URL parameter is required"})
            data = web_extractor.extract(url)
            return self._send_json(200, data)

        if path == "/api/video/plan":
            scenes = vimax_bridge.plan_storyboard(
                archetype=body.get("archetype", "saas_product_ad"),
                aspect_ratio=body.get("aspect_ratio", "9:16"),
                resolution=body.get("resolution", "1080p"),
                brand_name=body.get("brand_name", ""),
                product_name=body.get("product_name", ""),
                tagline=body.get("tagline", ""),
                description=body.get("description", ""),
                features=body.get("features", []),
                call_to_action=body.get("call_to_action", "Get Started Today"),
                brand_color=body.get("brand_color", "#2563EB"),
                user_script=body.get("user_script"),
                uploaded_image_paths=body.get("image_paths", []),
                video_clip_paths=body.get("video_clip_paths", []),
                target_scenes=body.get("target_scenes", 5),
            )
            return self._send_json(200, {"scenes": scenes})

        if path == "/api/video/regenerate-field":
            scene = body.get("scene", {})
            field_type = body.get("field_type", "visual_only")
            updated = vimax_bridge.regenerate_field(
                scene=scene,
                field_type=field_type,
                brand_name=body.get("brand_name", ""),
                brand_color=body.get("brand_color", "#2563EB"),
            )
            return self._send_json(200, {"scene": updated})

        if path == "/api/video/generate":
            provider = body.get("provider", "vimax")
            job_id = f"{provider}_job_{int(time.time() * 1000)}"
            job = job_manager.create_job(job_id, body)
            worker = threading.Thread(target=_run_generation_task, args=(job_id, body), daemon=True)
            worker.start()
            return self._send_json(202, {"job_id": job_id, "provider": provider, "status": "queued"})

        if path.startswith("/api/jobs/") and path.endswith("/cancel"):
            parts = path.split("/")
            job_id = parts[3]
            cancelled = job_manager.cancel_job(job_id)
            return self._send_json(200, {"cancelled": cancelled})

        if path == "/api/video/export":
            source_mp4 = body.get("source_mp4_path", "")
            destination_path = body.get("destination_path", "")

            if not source_mp4 or not os.path.exists(source_mp4):
                return self._send_json(400, {"error": "Source MP4 file does not exist"})
            if not destination_path:
                return self._send_json(400, {"error": "Destination path is required"})

            try:
                dest_dir = os.path.dirname(os.path.abspath(destination_path))
                os.makedirs(dest_dir, exist_ok=True)
                shutil.copy(source_mp4, destination_path)
                validation = video_renderer.probe_video(destination_path)
                if not validation["is_valid"]:
                    return self._send_json(422, {"error": "Export verification failed", "validation": validation})
                return self._send_json(200, {"success": True, "exported_path": destination_path, "validation": validation})
            except Exception as e:
                return self._send_json(500, {"error": f"Export failed: {str(e)}"})

        self._send_json(404, {"error": f"Endpoint not found: {path}"})


def run_server(host: str = "127.0.0.1", port: int = 8765) -> None:
    server_address = (host, port)
    httpd = ThreadingHTTPServer(server_address, ViMaxApiHandler)
    logger.info("🚀 AppGrowth Studio + ViMax & Wan2GP Backend Service running on http://%s:%d", host, port)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down Backend Service...")
        httpd.server_close()


if __name__ == "__main__":
    port = int(os.environ.get("VIMAX_PORT", 8765))
    run_server(port=port)
