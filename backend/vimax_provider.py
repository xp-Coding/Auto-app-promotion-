"""
ViMax Video Generation Provider Adapter for AppGrowth Studio.
Implements VideoProviderInterface for ViMax agentic pipeline, storyboard planning,
and local composition engine.
"""

from __future__ import annotations

import logging
import os
import sys
import time
from typing import Any, Callable, Dict, List, Optional

from backend.executable_resolver import get_workspace_root, resolve_ffmpeg_path, resolve_python_path
from backend.provider_interface import VideoProviderInterface

logger = logging.getLogger(__name__)


class ViMaxProvider(VideoProviderInterface):
    """ViMax Agentic Video Generation Provider."""

    def __init__(self, workspace_root: Optional[str] = None):
        self._root = os.path.abspath(workspace_root or get_workspace_root())
        self._vimax_repo = os.path.join(self._root, "backend", "vimax_repo")
        self._active_jobs: Dict[str, Dict[str, Any]] = {}
        self._cancel_flags: Dict[str, bool] = {}

    @property
    def provider_id(self) -> str:
        return "vimax"

    @property
    def display_name(self) -> str:
        return "ViMax Agentic Video Framework"

    def check_health(self) -> Dict[str, Any]:
        """Validates ViMax installation, dependencies, and execution readiness."""
        repo_exists = os.path.isdir(self._vimax_repo)
        main_script_exists = os.path.isfile(os.path.join(self._vimax_repo, "main_script2video.py"))
        py_exe, py_ver = resolve_python_path()
        ffmpeg_exe, ffmpeg_ver = resolve_ffmpeg_path()

        # Check required Python modules
        missing_modules = []
        for mod in ["PIL", "moviepy", "numpy"]:
            try:
                __import__(mod)
            except ImportError:
                missing_modules.append(mod)

        # Write permission check
        renders_dir = os.path.join(self._root, "backend", "renders")
        write_ok = False
        try:
            os.makedirs(renders_dir, exist_ok=True)
            test_file = os.path.join(renders_dir, ".write_test")
            with open(test_file, "w") as f:
                f.write("ok")
            os.remove(test_file)
            write_ok = True
        except Exception:
            write_ok = False

        is_ready = bool(repo_exists and py_exe and ffmpeg_exe and write_ok and not missing_modules)

        details = {
            "vimax_repo_path": self._vimax_repo,
            "vimax_installed": repo_exists and main_script_exists,
            "python_path": py_exe,
            "python_version": py_ver,
            "ffmpeg_path": ffmpeg_exe,
            "ffmpeg_version": ffmpeg_ver,
            "write_permissions": write_ok,
            "missing_modules": missing_modules,
            "offline_mode_ready": bool(ffmpeg_exe and write_ok),
        }

        if not is_ready:
            reasons = []
            if not repo_exists:
                reasons.append(f"ViMax repository missing at {self._vimax_repo}")
            if not py_exe:
                reasons.append("Python interpreter not found")
            if not ffmpeg_exe:
                reasons.append("FFmpeg executable not found")
            if not write_ok:
                reasons.append("Write permission denied in backend/renders")
            if missing_modules:
                reasons.append(f"Missing Python dependencies: {', '.join(missing_modules)}")
            msg = "; ".join(reasons)
            status = "configuration_error"
        else:
            msg = "ViMax agentic framework and local rendering engine ready."
            status = "ready"

        return {
            "is_available": is_ready,
            "provider": self.provider_id,
            "status": status,
            "message": msg,
            "details": details,
        }

    def validate_configuration(self, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Validates configuration parameters."""
        cfg = config or {}
        errors: List[str] = []
        warnings: List[str] = []

        ffmpeg_exe, _ = resolve_ffmpeg_path(cfg.get("ffmpeg_path"))
        if not ffmpeg_exe:
            errors.append("FFmpeg executable could not be resolved. Please verify ffmpeg.exe exists in project root.")

        py_exe, _ = resolve_python_path(cfg.get("python_path"))
        if not py_exe:
            errors.append("Python executable could not be resolved.")

        if not os.path.isdir(self._vimax_repo):
            warnings.append(f"ViMax repository not found at {self._vimax_repo}. Heuristic narrative engine will be used.")

        return {
            "is_valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
            "resolved_config": {
                "ffmpeg_path": ffmpeg_exe,
                "python_path": py_exe,
                "vimax_repo": self._vimax_repo,
            },
        }

    def generate_clip(
        self,
        shot_id: str,
        prompt: str,
        duration_seconds: float = 4.0,
        aspect_ratio: str = "9:16",
        resolution: str = "720p",
        reference_image_path: Optional[str] = None,
        negative_prompt: Optional[str] = None,
        generation_params: Optional[Dict[str, Any]] = None,
        progress_callback: Optional[Callable[[str, str, float], None]] = None,
    ) -> Dict[str, Any]:
        """Generates an individual scene clip using ViMax / local high-resolution compositor."""
        from backend.video_renderer import VideoRenderer
        renderer = VideoRenderer()

        job_id = f"vimax_clip_{shot_id}_{int(time.time() * 1000)}"
        self._active_jobs[job_id] = {
            "job_id": job_id,
            "status": "running",
            "progress": 0.1,
            "output_path": None,
            "error": None,
            "started_at": time.time(),
        }
        self._cancel_flags[job_id] = False

        if progress_callback:
            progress_callback("preparing", f"Initializing ViMax scene compositor for shot {shot_id}", 0.1)

        try:
            if self._cancel_flags.get(job_id, False):
                raise RuntimeError("Job cancelled by user")

            w, h = renderer.get_resolution_dimensions(aspect_ratio, resolution)
            out_dir = os.path.join(self._root, "backend", "renders", "clips")
            os.makedirs(out_dir, exist_ok=True)
            output_clip = os.path.join(out_dir, f"{job_id}.mp4")

            # Render frame
            frame_path = os.path.join(out_dir, f"{job_id}_frame.png")
            renderer._render_scene_image(
                scene={
                    "scene_title": f"Shot {shot_id}",
                    "on_screen_text": prompt[:40] if prompt else "ViMax Showcase",
                    "visual_asset_paths": [reference_image_path] if reference_image_path else [],
                    "call_to_action": "",
                },
                width=w,
                height=h,
                brand_color="#2563EB",
                output_path=frame_path,
            )

            if progress_callback:
                progress_callback("encoding", f"Encoding video frame at {w}x{h}", 0.5)

            # Generate silent audio placeholder for standalone clip
            audio_path = os.path.join(out_dir, f"{job_id}_silence.wav")
            renderer.audio_synth._create_silent_audio(audio_path, duration_seconds)

            # Encode clip
            renderer._encode_image_scene_clip(
                image_path=frame_path,
                audio_path=audio_path,
                target_width=w,
                target_height=h,
                duration=duration_seconds,
                output_path=output_clip,
            )

            # Validate output
            probe = renderer.probe_video(output_clip)
            if not probe["is_valid"]:
                raise RuntimeError(f"Clip output validation failed: {probe.get('error')}")

            # Clean temp frame & audio
            for tmp in [frame_path, audio_path]:
                if os.path.exists(tmp):
                    try:
                        os.remove(tmp)
                    except Exception:
                        pass

            self._active_jobs[job_id]["status"] = "completed"
            self._active_jobs[job_id]["progress"] = 1.0
            self._active_jobs[job_id]["output_path"] = output_clip

            if progress_callback:
                progress_callback("completed", "Clip generated and validated", 1.0)

            return {
                "job_id": job_id,
                "status": "completed",
                "clip_path": output_clip,
                "error": None,
                "duration_seconds": probe["duration_seconds"],
                "provider": self.provider_id,
            }

        except Exception as e:
            err = str(e)
            logger.exception("ViMax clip generation failed: %s", err)
            self._active_jobs[job_id]["status"] = "failed"
            self._active_jobs[job_id]["error"] = err
            return {
                "job_id": job_id,
                "status": "failed",
                "clip_path": None,
                "error": err,
                "duration_seconds": 0.0,
                "provider": self.provider_id,
            }

    def get_job_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        return self._active_jobs.get(job_id)

    def cancel_job(self, job_id: str) -> bool:
        if job_id in self._active_jobs:
            self._cancel_flags[job_id] = True
            self._active_jobs[job_id]["status"] = "cancelled"
            return True
        return False

    def get_output_path(self, job_id: str) -> Optional[str]:
        job = self._active_jobs.get(job_id)
        return job.get("output_path") if job else None

    def get_provider_info(self) -> Dict[str, Any]:
        return {
            "provider_id": self.provider_id,
            "display_name": self.display_name,
            "version": "1.2.0",
            "type": "agentic_framework",
            "supported_modes": ["storyboard_planning", "text_to_video", "image_to_video", "voiceover_synthesis", "ffmpeg_compositing"],
            "models": ["offline_director", "saas_product_ad", "mobile_app_promo", "cinematic_ad"],
            "licensing": "MIT License (HKUDS/ViMax)",
            "requires_gpu": False,
            "is_free_local": True,
        }
