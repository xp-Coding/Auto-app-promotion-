"""
Wan2GP AI Video Diffusion Provider Adapter for AppGrowth Studio.
Integrates with deepbeepmeep/Wan2GP (https://github.com/deepbeepmeep/Wan2GP)
for local GPU-accelerated video clip generation with strict hardware safeguards,
job tracking, and license attribution.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

from backend.executable_resolver import detect_gpu_hardware, get_workspace_root, resolve_ffmpeg_path, resolve_python_path
from backend.provider_interface import VideoProviderInterface

logger = logging.getLogger(__name__)

# Attribution constant as required by Wan2GP Terms and Conditions
WAN2GP_ATTRIBUTION = "Powered by Wan2GP (deepbeepmeep/Wan2GP). Subject to Wan2GP Terms and Conditions."

# Known Wan2GP Supported Models & Hardware Requirements
WAN2GP_MODELS = {
    "wan2.1_t2v_1.3B": {
        "name": "Wan 2.1 T2V 1.3B (Low VRAM Fast)",
        "modes": ["t2v"],
        "min_vram_gb": 6.0,
        "recommended_vram_gb": 8.0,
        "est_download_size_gb": 3.8,
        "default_steps": 20,
        "default_resolution": "832x480",
    },
    "wan2.1_i2v_720p_14B": {
        "name": "Wan 2.1 I2V 720p 14B (High Quality)",
        "modes": ["i2v"],
        "min_vram_gb": 14.0,
        "recommended_vram_gb": 24.0,
        "est_download_size_gb": 28.0,
        "default_steps": 30,
        "default_resolution": "1280x720",
    },
    "wan2.1_t2v_14B": {
        "name": "Wan 2.1 T2V 14B (Full Precision)",
        "modes": ["t2v"],
        "min_vram_gb": 16.0,
        "recommended_vram_gb": 24.0,
        "est_download_size_gb": 28.0,
        "default_steps": 30,
        "default_resolution": "1280x720",
    },
    "ltx2_22B_distilled": {
        "name": "LTX-Video 2.0 (Distilled Fast)",
        "modes": ["t2v", "i2v"],
        "min_vram_gb": 8.0,
        "recommended_vram_gb": 12.0,
        "est_download_size_gb": 14.0,
        "default_steps": 8,
        "default_resolution": "1280x704",
    },
    "hunyuan_video": {
        "name": "Hunyuan Video (Tencent)",
        "modes": ["t2v"],
        "min_vram_gb": 16.0,
        "recommended_vram_gb": 24.0,
        "est_download_size_gb": 24.0,
        "default_steps": 30,
        "default_resolution": "1280x720",
    },
}


class Wan2GPProvider(VideoProviderInterface):
    """Wan2GP Local AI Video Diffusion Provider Adapter."""

    def __init__(self, workspace_root: Optional[str] = None):
        self._root = os.path.abspath(workspace_root or get_workspace_root())
        self._config_file = os.path.join(self._root, "backend", "configs", "wan2gp.json")
        self._config = self._load_config()
        self._active_jobs: Dict[str, Dict[str, Any]] = {}
        self._cancel_flags: Dict[str, bool] = {}
        self._model_lock = threading.Lock()
        self._currently_loaded_model: Optional[str] = None

    @property
    def provider_id(self) -> str:
        return "wan2gp"

    @property
    def display_name(self) -> str:
        return "Wan2GP Local Video Diffusion"

    def _load_config(self) -> Dict[str, Any]:
        """Loads saved Wan2GP configuration or defaults."""
        defaults = {
            "install_dir": os.path.join(self._root, "backend", "wan2gp_repo"),
            "python_env_path": "",
            "model_type": "wan2.1_t2v_1.3B",
            "output_dir": os.path.join(self._root, "backend", "renders", "wan2gp_clips"),
            "num_inference_steps": 20,
            "resolution": "832x480",
            "remote_api_url": "",
            "auto_unload_model": True,
        }
        if os.path.exists(self._config_file):
            try:
                with open(self._config_file, "r", encoding="utf-8") as f:
                    saved = json.load(f)
                    defaults.update(saved)
            except Exception:
                pass
        return defaults

    def save_config(self, new_cfg: Dict[str, Any]) -> Dict[str, Any]:
        """Updates and persists Wan2GP configuration."""
        self._config.update(new_cfg)
        os.makedirs(os.path.dirname(self._config_file), exist_ok=True)
        with open(self._config_file, "w", encoding="utf-8") as f:
            json.dump(self._config, f, indent=2)
        return self._config

    def check_health(self) -> Dict[str, Any]:
        """
        Inspects GPU hardware suitability, Wan2GP installation,
        Python environment, and model readiness.
        """
        gpu_info = detect_gpu_hardware()
        install_dir = os.path.abspath(self._config.get("install_dir", ""))
        repo_installed = os.path.isdir(install_dir)
        api_wrapper_exists = os.path.isfile(os.path.join(install_dir, "shared", "api.py")) or os.path.isfile(os.path.join(install_dir, "wgp.py"))

        py_path = self._config.get("python_env_path", "")
        py_exe, py_ver = resolve_python_path(py_path if py_path else None)

        selected_model = self._config.get("model_type", "wan2.1_t2v_1.3B")
        model_meta = WAN2GP_MODELS.get(selected_model, WAN2GP_MODELS["wan2.1_t2v_1.3B"])
        min_vram = model_meta["min_vram_gb"]

        has_adequate_vram = gpu_info["has_cuda"] and gpu_info["total_vram_gb"] >= min_vram

        # Construct status and message
        if not gpu_info["has_cuda"]:
            status = "hardware_unsupported"
            message = (
                f"Unsupported Hardware: Wan2GP requires an NVIDIA GPU with CUDA support and at least "
                f"{min_vram:.0f} GB dedicated VRAM. Detected: "
                f"{gpu_info['raw_controllers'][0]['name'] if gpu_info['raw_controllers'] else 'Integrated Graphics'} "
                f"({gpu_info['raw_controllers'][0]['vram_gb'] if gpu_info['raw_controllers'] else 0.0:.1f} GB VRAM, No CUDA). "
                f"Dedicated NVIDIA GPU (RTX 3060/4060 or higher) or external compute is required."
            )
        elif not has_adequate_vram:
            status = "insufficient_vram"
            message = (
                f"Insufficient VRAM: Selected model '{model_meta['name']}' requires at least {min_vram:.0f} GB VRAM. "
                f"Detected system VRAM: {gpu_info['total_vram_gb']:.1f} GB. Consider selecting a lighter model like Wan 2.1 1.3B."
            )
        elif not repo_installed or not api_wrapper_exists:
            status = "not_installed"
            message = (
                f"Wan2GP repository not found at: {install_dir}. "
                f"To install, clone: git clone https://github.com/deepbeepmeep/Wan2GP.git into {install_dir}"
            )
        else:
            status = "ready"
            message = f"Wan2GP is ready for local generation on {gpu_info['gpus'][0]['name']} ({gpu_info['total_vram_gb']:.1f} GB VRAM)."

        is_available = status == "ready"

        return {
            "is_available": is_available,
            "provider": self.provider_id,
            "status": status,
            "message": message,
            "attribution": WAN2GP_ATTRIBUTION,
            "details": {
                "hardware": gpu_info,
                "install_dir": install_dir,
                "is_installed": repo_installed and api_wrapper_exists,
                "python_executable": py_exe,
                "python_version": py_ver,
                "selected_model": selected_model,
                "selected_model_info": model_meta,
                "official_repo": "https://github.com/deepbeepmeep/Wan2GP",
                "license": "Wan2GP Terms and Conditions",
            },
        }

    def validate_configuration(self, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Validates configuration settings, model limits, and hardware safety."""
        cfg = dict(self._config)
        if config:
            cfg.update(config)

        errors: List[str] = []
        warnings: List[str] = []

        gpu_info = detect_gpu_hardware()
        if not gpu_info["has_cuda"]:
            warnings.append(
                "No NVIDIA CUDA GPU detected on this system. Wan2GP will not be able to generate diffusion clips locally."
            )

        model_type = cfg.get("model_type", "wan2.1_t2v_1.3B")
        if model_type not in WAN2GP_MODELS:
            errors.append(f"Unknown Wan2GP model '{model_type}'. Choose from: {list(WAN2GP_MODELS.keys())}")
        else:
            required_vram = WAN2GP_MODELS[model_type]["min_vram_gb"]
            if gpu_info["has_cuda"] and gpu_info["total_vram_gb"] < required_vram:
                warnings.append(
                    f"Selected model '{model_type}' requires {required_vram} GB VRAM, but detected only {gpu_info['total_vram_gb']} GB."
                )

        install_dir = cfg.get("install_dir", "")
        if install_dir and not os.path.exists(install_dir):
            warnings.append(f"Installation directory does not exist: {install_dir}")

        return {
            "is_valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
            "resolved_config": cfg,
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
        """
        Executes a video clip generation request using Wan2GP.
        Validates hardware, mode compatibility (T2V vs I2V),
        prevents simultaneous model contention, and tracks progress.
        """
        job_id = f"wan2gp_clip_{shot_id}_{int(time.time() * 1000)}"
        out_dir = os.path.abspath(self._config.get("output_dir", os.path.join(self._root, "backend", "renders", "wan2gp_clips")))
        os.makedirs(out_dir, exist_ok=True)
        final_clip_path = os.path.join(out_dir, f"{job_id}.mp4")

        self._active_jobs[job_id] = {
            "job_id": job_id,
            "status": "queued",
            "progress": 0.0,
            "clip_path": None,
            "error": None,
            "started_at": time.time(),
        }
        self._cancel_flags[job_id] = False

        # 1. Hardware Safeguard Check
        health = self.check_health()
        if not health["is_available"]:
            err_msg = f"Cannot generate with Wan2GP: {health['message']}"
            self._active_jobs[job_id]["status"] = "failed"
            self._active_jobs[job_id]["error"] = err_msg
            if progress_callback:
                progress_callback("failed", err_msg, 0.0)
            return {
                "job_id": job_id,
                "status": "failed",
                "clip_path": None,
                "error": err_msg,
                "duration_seconds": 0.0,
                "provider": self.provider_id,
            }

        # 2. Model & Mode Compatibility Check
        selected_model = self._config.get("model_type", "wan2.1_t2v_1.3B")
        model_meta = WAN2GP_MODELS.get(selected_model, WAN2GP_MODELS["wan2.1_t2v_1.3B"])
        is_i2v_mode = bool(reference_image_path and os.path.isfile(reference_image_path))

        if is_i2v_mode and "i2v" not in model_meta["modes"]:
            err_msg = (
                f"Selected model '{model_meta['name']}' only supports text-to-video (t2v). "
                f"For image-to-video, please select an I2V-capable model like 'wan2.1_i2v_720p_14B'."
            )
            self._active_jobs[job_id]["status"] = "failed"
            self._active_jobs[job_id]["error"] = err_msg
            return {
                "job_id": job_id,
                "status": "failed",
                "clip_path": None,
                "error": err_msg,
                "duration_seconds": 0.0,
                "provider": self.provider_id,
            }

        # 3. Model Locking & Single Model Resource Safety
        acquired = self._model_lock.acquire(blocking=False)
        if not acquired:
            err_msg = "Another Wan2GP generation job is currently occupying the GPU. Multi-model concurrency is disabled to avoid OOM."
            self._active_jobs[job_id]["status"] = "failed"
            self._active_jobs[job_id]["error"] = err_msg
            return {
                "job_id": job_id,
                "status": "failed",
                "clip_path": None,
                "error": err_msg,
                "duration_seconds": 0.0,
                "provider": self.provider_id,
            }

        try:
            self._active_jobs[job_id]["status"] = "running"
            if progress_callback:
                progress_callback("preparing", f"Loading Wan2GP model {model_meta['name']} into VRAM", 0.1)

            # 4. Invoke Wan2GP via in-process API wrapper or CLI
            install_dir = os.path.abspath(self._config.get("install_dir", ""))
            py_exe, _ = resolve_python_path(self._config.get("python_env_path"))

            # Build generation manifest settings
            res_str = self._resolve_resolution_string(aspect_ratio, resolution)
            steps = int(self._config.get("num_inference_steps", model_meta["default_steps"]))

            settings = {
                "model_type": selected_model,
                "prompt": prompt,
                "negative_prompt": negative_prompt or "blurry, low quality, distorted, artifact",
                "resolution": res_str,
                "num_inference_steps": steps,
                "duration_seconds": max(2.0, min(duration_seconds, 10.0)),
                "output_dir": out_dir,
            }
            if is_i2v_mode:
                settings["image_path"] = reference_image_path

            # Attempt via shared/api.py in Python path
            success, generated_file, err = self._execute_wan2gp_task(install_dir, py_exe, settings, job_id, progress_callback)

            if success and generated_file and os.path.isfile(generated_file):
                # Move to standard final_clip_path
                shutil.copy(generated_file, final_clip_path)
                self._active_jobs[job_id]["status"] = "completed"
                self._active_jobs[job_id]["progress"] = 1.0
                self._active_jobs[job_id]["clip_path"] = final_clip_path
                return {
                    "job_id": job_id,
                    "status": "completed",
                    "clip_path": final_clip_path,
                    "error": None,
                    "duration_seconds": duration_seconds,
                    "provider": self.provider_id,
                }
            else:
                raise RuntimeError(err or "Wan2GP execution did not yield a valid output clip.")

        except Exception as e:
            err = str(e)
            logger.exception("Wan2GP generation failed: %s", err)
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
        finally:
            if self._config.get("auto_unload_model", True):
                self._release_model_resources()
            self._model_lock.release()

    def _execute_wan2gp_task(
        self,
        install_dir: str,
        python_exe: Optional[str],
        settings: Dict[str, Any],
        job_id: str,
        progress_callback: Optional[Callable[[str, str, float], None]],
    ) -> tuple[bool, Optional[str], Optional[str]]:
        """
        Executes Wan2GP task using its documented shared/api.py interface.
        If python_exe points to an isolated venv, runs in a dedicated subprocess.
        """
        # Create temp manifest file
        manifest_dir = os.path.join(self._root, "backend", "cache", "wan2gp_manifests")
        os.makedirs(manifest_dir, exist_ok=True)
        manifest_path = os.path.join(manifest_dir, f"{job_id}.json")
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2)

        runner_script = os.path.join(manifest_dir, f"run_{job_id}.py")
        script_code = f"""
import sys, os, json
from pathlib import Path

# Add Wan2GP repo to sys.path
wan_root = Path(r"{install_dir}")
sys.path.insert(0, str(wan_root))

try:
    from shared.api import init
    session = init(root=wan_root, console_output=True)
    with open(r"{manifest_path}", "r", encoding="utf-8") as f:
        task_settings = json.load(f)
    job = session.submit_task(task_settings)
    result = job.result()
    if result.success and result.generated_files:
        print(f"WAN2GP_OUTPUT_SUCCESS:{{result.generated_files[0]}}")
    else:
        errs = "; ".join([e.message for e in result.errors]) if result.errors else "Unknown generation error"
        print(f"WAN2GP_OUTPUT_FAILED:{{errs}}")
except Exception as e:
    print(f"WAN2GP_OUTPUT_FAILED:{{str(e)}}")
"""
        with open(runner_script, "w", encoding="utf-8") as f:
            f.write(script_code)

        try:
            exe = python_exe or sys.executable
            proc = subprocess.Popen(
                [exe, runner_script],
                cwd=install_dir if os.path.isdir(install_dir) else self._root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )

            # Monitor process
            output_file = None
            err_msg = None
            while True:
                if self._cancel_flags.get(job_id, False):
                    proc.terminate()
                    return False, None, "Job cancelled by user"
                line = proc.stdout.readline()
                if not line and proc.poll() is not None:
                    break
                if line:
                    line_str = line.strip()
                    if "WAN2GP_OUTPUT_SUCCESS:" in line_str:
                        output_file = line_str.split("WAN2GP_OUTPUT_SUCCESS:")[1].strip()
                    elif "WAN2GP_OUTPUT_FAILED:" in line_str:
                        err_msg = line_str.split("WAN2GP_OUTPUT_FAILED:")[1].strip()
                    elif progress_callback:
                        progress_callback("generating", line_str[:60], 0.6)

            stderr = proc.stderr.read()
            if proc.returncode != 0 and not output_file:
                return False, None, err_msg or f"Subprocess exited with code {proc.returncode}: {stderr}"

            if output_file and os.path.isfile(output_file):
                return True, output_file, None
            return False, None, err_msg or "No output video file was generated"

        finally:
            for tmp in [manifest_path, runner_script]:
                if os.path.exists(tmp):
                    try:
                        os.remove(tmp)
                    except Exception:
                        pass

    def _resolve_resolution_string(self, aspect_ratio: str, resolution: str) -> str:
        """Maps aspect ratio and resolution to Wan2GP supported dimensions."""
        if aspect_ratio == "9:16":
            return "720x1280" if "1080" in resolution or "720" in resolution else "480x832"
        elif aspect_ratio == "1:1":
            return "720x720"
        else:  # 16:9
            return "1280x720" if "1080" in resolution or "720" in resolution else "832x480"

    def _release_model_resources(self) -> None:
        """Safely cleans CUDA memory cache."""
        try:
            import gc
            gc.collect()
            try:
                import torch
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
            except ImportError:
                pass
        except Exception:
            pass

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
        return job.get("clip_path") if job else None

    def get_provider_info(self) -> Dict[str, Any]:
        return {
            "provider_id": self.provider_id,
            "display_name": self.display_name,
            "attribution": WAN2GP_ATTRIBUTION,
            "official_repo": "https://github.com/deepbeepmeep/Wan2GP",
            "supported_models": list(WAN2GP_MODELS.keys()),
            "models_metadata": WAN2GP_MODELS,
            "hardware_requirements": {
                "gpu": "NVIDIA RTX 3060 / 4060 or higher",
                "min_vram_gb": 6.0,
                "cuda_required": True,
            },
            "licensing": "Subject to Wan2GP Terms and Conditions. Disclose usage in UI and docs.",
        }
