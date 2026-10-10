"""
ViMax Agentic Framework Bridge for AppGrowth Studio.
Interfaces with ViMax pipelines, provider configs, narrative planning agents,
and multi-input promotional storyboard generation.
Includes comprehensive diagnostics and path resolution.
"""

from __future__ import annotations

import json
import logging
import os
import re
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from backend.executable_resolver import detect_gpu_hardware, get_workspace_root, resolve_ffmpeg_path, resolve_python_path

logger = logging.getLogger(__name__)

# Add ViMax repo to sys.path
VIMAX_REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "vimax_repo"))
if VIMAX_REPO_DIR not in sys.path:
    sys.path.insert(0, VIMAX_REPO_DIR)


class ViMaxBridge:
    def __init__(self, workspace_root: Optional[str] = None):
        self.workspace_root = os.path.abspath(workspace_root or get_workspace_root())
        self.configs_dir = os.path.join(self.workspace_root, "backend", "configs")
        os.makedirs(self.configs_dir, exist_ok=True)
        self.config_path = os.path.join(self.configs_dir, "agent.local.yaml")
        self.vimax_repo_path = os.path.join(self.workspace_root, "backend", "vimax_repo")

    def run_diagnostics(self) -> Dict[str, Any]:
        """
        Runs comprehensive diagnostic checks on ViMax installation, configuration,
        dependencies, provider readiness, and write permissions.
        Ensures secrets are never exposed in logs.
        """
        py_exe, py_ver = resolve_python_path()
        ffmpeg_exe, ffmpeg_ver = resolve_ffmpeg_path()
        gpu_info = detect_gpu_hardware()

        # Check repository
        repo_exists = os.path.isdir(self.vimax_repo_path)
        main_script_exists = os.path.isfile(os.path.join(self.vimax_repo_path, "main_script2video.py"))
        agent_script_exists = os.path.isfile(os.path.join(self.vimax_repo_path, "main_agent.py"))

        # Check Python dependencies
        deps_status = {}
        for pkg in ["PIL", "moviepy", "numpy", "edge_tts", "yaml", "requests"]:
            try:
                mod = __import__(pkg)
                ver = getattr(mod, "__version__", "installed")
                deps_status[pkg] = {"installed": True, "version": str(ver)}
            except ImportError:
                deps_status[pkg] = {"installed": False, "version": None}

        # Check write permissions in critical folders
        folders_to_test = [
            ("renders", os.path.join(self.workspace_root, "backend", "renders")),
            ("cache", os.path.join(self.workspace_root, "backend", "cache")),
            ("configs", self.configs_dir),
        ]
        write_status = {}
        for name, folder in folders_to_test:
            try:
                os.makedirs(folder, exist_ok=True)
                test_f = os.path.join(folder, ".perm_test")
                with open(test_f, "w") as f:
                    f.write("test")
                os.remove(test_f)
                write_status[name] = {"path": folder, "writable": True}
            except Exception as e:
                write_status[name] = {"path": folder, "writable": False, "error": str(e)}

        # Load sanitized configuration
        cfg = self._load_config()
        sanitized_cfg = {
            "llm_provider": cfg.get("llm", {}).get("model_provider", "local"),
            "llm_configured": bool(os.environ.get("VIMAX_LLM_API_KEY") or os.environ.get("GEMINI_API_KEY") or cfg.get("llm", {}).get("api_key")),
            "image_provider": cfg.get("image", {}).get("provider", "local_procedural"),
            "video_provider": cfg.get("video", {}).get("provider", "local_compositor"),
        }

        all_deps_ok = all(v["installed"] for v in deps_status.values())
        all_writable = all(v["writable"] for v in write_status.values())
        is_ready = bool(py_exe and ffmpeg_exe and all_writable and all_deps_ok)

        return {
            "is_ready": is_ready,
            "overall_status": "healthy" if is_ready else "degraded",
            "vimax_installation": {
                "repo_path": self.vimax_repo_path,
                "exists": repo_exists,
                "has_script2video": main_script_exists,
                "has_agent_runtime": agent_script_exists,
            },
            "executables": {
                "python": {"path": py_exe, "version": py_ver, "valid": bool(py_exe)},
                "ffmpeg": {"path": ffmpeg_exe, "version": ffmpeg_ver, "valid": bool(ffmpeg_exe)},
            },
            "dependencies": deps_status,
            "file_system_permissions": write_status,
            "hardware": gpu_info,
            "configuration": sanitized_cfg,
        }

    def get_provider_status(self) -> Dict[str, Any]:
        """Inspects and returns the active health and configuration of all AI providers."""
        config = self._load_config()
        llm_cfg = config.get("llm", {})
        image_cfg = config.get("image", {})
        video_cfg = config.get("video", {})

        llm_key = os.environ.get("VIMAX_LLM_API_KEY") or os.environ.get("GEMINI_API_KEY") or os.environ.get("OPENAI_API_KEY") or llm_cfg.get("api_key", "")
        has_llm = bool(llm_key or llm_cfg.get("base_url", "").startswith("http://localhost") or llm_cfg.get("base_url", "").startswith("http://127.0.0.1"))

        image_key = os.environ.get("VIMAX_IMAGE_API_KEY") or image_cfg.get("api_key", "") or llm_key
        has_image = bool(image_key)

        video_key = os.environ.get("VIMAX_VIDEO_API_KEY") or video_cfg.get("api_key", "")
        has_video = bool(video_key)

        ffmpeg_exe, _ = resolve_ffmpeg_path()
        ffmpeg_installed = bool(ffmpeg_exe and os.path.exists(ffmpeg_exe))

        return {
            "status": "ready",
            "framework": "ViMax Agentic Video Framework 1.2.0",
            "offline_mode_available": True,
            "ffmpeg_available": ffmpeg_installed,
            "ffmpeg_path": ffmpeg_exe,
            "speech_synthesis": "Native Windows SAPI & Edge-TTS (Free & Local)",
            "llm": {
                "available": has_llm,
                "provider": llm_cfg.get("model_provider", "local_heuristic" if not has_llm else "openai/gemini"),
                "model": llm_cfg.get("model", "offline_template_engine" if not has_llm else "gemini-2.5-flash"),
                "configured": bool(llm_key),
            },
            "image_generation": {
                "available": has_image,
                "provider": image_cfg.get("provider", "procedural_canvas_library" if not has_image else "nanobanana/openrouter"),
                "configured": has_image,
                "mode": "ai_generative" if has_image else "local_procedural_graphics",
            },
            "video_generation": {
                "available": has_video,
                "provider": video_cfg.get("provider", "cinematic_motion_compositor" if not has_video else "veo/doubao/openrouter"),
                "configured": has_video,
                "mode": "ai_video_diffusion" if has_video else "motion_keyframes_and_compositing",
            },
            "daily_target": "5 videos/day (Quota-Safe Hybrid Architecture)",
        }

    def _load_config(self) -> Dict[str, Any]:
        """Loads YAML config or returns defaults."""
        import yaml
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, "r", encoding="utf-8") as f:
                    return yaml.safe_load(f) or {}
            except Exception:
                pass
        return {
            "llm": {"model_provider": "local", "model": "offline_director", "api_key": ""},
            "image": {"provider": "local_procedural", "api_key": ""},
            "video": {"provider": "local_compositor", "api_key": ""},
        }

    def save_config(self, new_config: Dict[str, Any]) -> Dict[str, Any]:
        """Persists updated provider configuration to local YAML."""
        import yaml
        current = self._load_config()
        current.update(new_config)
        with open(self.config_path, "w", encoding="utf-8") as f:
            yaml.safe_dump(current, f)
        return current

    def plan_storyboard(
        self,
        archetype: str = "saas_product_ad",
        aspect_ratio: str = "9:16",
        resolution: str = "1080p",
        brand_name: str = "",
        product_name: str = "",
        tagline: str = "",
        description: str = "",
        features: Optional[List[str]] = None,
        call_to_action: str = "Get Started Today",
        brand_color: str = "#2563EB",
        user_script: Optional[str] = None,
        uploaded_image_paths: Optional[List[str]] = None,
        video_clip_paths: Optional[List[str]] = None,
        website_url: Optional[str] = None,
        target_scenes: int = 5,
    ) -> List[Dict[str, Any]]:
        """
        Plans a multi-scene promotional storyboard with discrete, independent text fields,
        stable scene IDs, and designated visual assets.
        Preserves original user script whenever provided.
        """
        features_list = features or []
        brand = brand_name or product_name or "AppGrowth"
        cta = call_to_action or "Get Started Now"
        user_images = uploaded_image_paths or []
        user_clips = video_clip_paths or []

        # If user provided an existing script, segment and preserve it without changing words
        if user_script and user_script.strip():
            return self._plan_from_user_script(
                script=user_script.strip(),
                brand=brand,
                user_images=user_images,
                user_clips=user_clips,
                cta=cta,
                brand_color=brand_color,
            )

        # Plan according to the requested promotional archetype
        return self._plan_archetype_storyboard(
            archetype=archetype,
            brand=brand,
            tagline=tagline or f"Supercharge your results with {brand}",
            description=description or "The intuitive platform designed to streamline your workflow and accelerate growth.",
            features=features_list,
            cta=cta,
            brand_color=brand_color,
            user_images=user_images,
            user_clips=user_clips,
            target_scenes=max(3, min(target_scenes, 8)),
        )

    def _plan_from_user_script(
        self,
        script: str,
        brand: str,
        user_images: List[str],
        user_clips: List[str],
        cta: str,
        brand_color: str,
    ) -> List[Dict[str, Any]]:
        """
        Converts an existing user script into storyboard scenes while strictly preserving
        every word of the original text.
        """
        sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+|\n+", script) if s.strip()]
        if not sentences:
            sentences = [script.strip()]

        scenes: List[Dict[str, Any]] = []
        for idx, sentence in enumerate(sentences):
            scene_id = f"scene_{idx + 1}_{uuid.uuid4().hex[:6]}"
            is_first = idx == 0
            is_last = idx == len(sentences) - 1

            title = f"{brand} Overview" if is_first else (f"{cta}" if is_last else f"Key Advantage {idx}")
            on_screen = sentence if len(sentence) <= 45 else (sentence[:42].rsplit(" ", 1)[0] + "...")
            
            # Select visual asset from user media or procedural gradient
            asset_path = None
            if idx < len(user_clips):
                asset_path = user_clips[idx]
                source_type = "user_video_clip"
            elif idx < len(user_images):
                asset_path = user_images[idx]
                source_type = "user_screenshot"
            else:
                source_type = "built_in_gradient"

            scenes.append({
                "id": scene_id,
                "scene_title": title,
                "on_screen_text": on_screen,
                "voice_over_narration": sentence,
                "subtitle_text": sentence,
                "visual_description": f"High impact visual composition showcasing: {sentence[:60]}",
                "visual_generation_prompt": f"Minimalist professional UI presentation, modern typography, brand theme {brand_color}",
                "visual_source_type": source_type,
                "visual_asset_paths": [asset_path] if asset_path else [],
                "duration_seconds": max(3.0, round(len(sentence.split()) * 0.45, 1)),
                "transition": "fade" if idx > 0 else "cut",
                "call_to_action": cta if is_last else "",
            })
        return scenes

    def _plan_archetype_storyboard(
        self,
        archetype: str,
        brand: str,
        tagline: str,
        description: str,
        features: List[str],
        cta: str,
        brand_color: str,
        user_images: List[str],
        user_clips: List[str],
        target_scenes: int,
    ) -> List[Dict[str, Any]]:
        """Synthesizes structured scenes tailored for professional commercial archetypes."""
        feat1 = features[0] if len(features) > 0 else "Intelligent Automation"
        feat2 = features[1] if len(features) > 1 else "Real-Time Insights"
        feat3 = features[2] if len(features) > 2 else "Seamless Team Workflow"

        templates = {
            "saas_product_ad": [
                {
                    "title": "Stop Wasting Hours",
                    "screen": "Tired of manual, fragmented workflows?",
                    "voice": "Are you still losing hours every week juggling complex, fragmented tools?",
                    "vis": "Frustrated professional in modern office surrounded by chaotic UI elements.",
                    "dur": 3.5,
                },
                {
                    "title": f"Meet {brand}",
                    "screen": f"{brand}: {tagline}",
                    "voice": f"Meet {brand}. The modern platform built to streamline everything you do.",
                    "vis": f"Sleek hero showcase of {brand} with ambient lighting and clean typography.",
                    "dur": 4.0,
                },
                {
                    "title": "Supercharged Speed",
                    "screen": "Automate Routine Tasks Instantly",
                    "voice": f"With {feat1}, your entire workflow accelerates effortlessly.",
                    "vis": "Smooth UI demonstration showing lightning-fast automation and intuitive cards.",
                    "dur": 3.8,
                },
                {
                    "title": "Complete Clarity",
                    "screen": f"{feat2} at your fingertips",
                    "voice": f"Gain immediate control with {feat2} and actionable performance visibility.",
                    "vis": "Analytical dashboard visualization with clean charts and metric counters.",
                    "dur": 3.8,
                },
                {
                    "title": f"Try {brand} Free",
                    "screen": f"{cta}",
                    "voice": f"Transform your productivity today. Visit our website and {cta.lower()}.",
                    "vis": f"Polished brand end-card featuring {brand} logo, primary button, and clean backdrop.",
                    "dur": 4.0,
                },
            ],
            "mobile_app_promo": [
                {
                    "title": "Your Day, Upgraded",
                    "screen": f"Meet {brand}",
                    "voice": "Ready to experience a smarter way to get things done on the go?",
                    "vis": "Perspective floating smartphone mockup displaying the mobile application.",
                    "dur": 3.5,
                },
                {
                    "title": "Built for Mobile",
                    "screen": f"{tagline}",
                    "voice": f"{brand} gives you powerful capabilities right in the palm of your hand.",
                    "vis": "Crisp app screenshot inside an elegant bezel-less device frame.",
                    "dur": 3.8,
                },
                {
                    "title": "Instant Results",
                    "screen": f"{feat1}",
                    "voice": f"Experience {feat1} with instant, buttery-smooth interactions.",
                    "vis": "Close-up gesture animation interacting with app interface cards.",
                    "dur": 3.5,
                },
                {
                    "title": "Install Today",
                    "screen": f"{cta}",
                    "voice": f"Download {brand} now and elevate your daily routine.",
                    "vis": "App Store & Google Play badges with five-star customer satisfaction badge.",
                    "dur": 4.0,
                },
            ],
            "cinematic_ad": [
                {
                    "title": "The Standard Has Changed",
                    "screen": "A New Horizon in Performance",
                    "voice": "In an era where every second matters, good enough is no longer an option.",
                    "vis": "Deep cinematic widescreen backdrop with subtle volumetric lighting.",
                    "dur": 4.2,
                },
                {
                    "title": "Engineered for Mastery",
                    "screen": f"{brand}",
                    "voice": f"Introducing {brand}. Precision craftsmanship meets next-generation intelligence.",
                    "vis": "Dramatic metallic reveal of the product logo with subtle light streaks.",
                    "dur": 4.5,
                },
                {
                    "title": "Limitless Potential",
                    "screen": f"{feat1} & {feat2}",
                    "voice": f"Harness {feat1} engineered to deliver flawless outcomes under any condition.",
                    "vis": "High-framerate abstract motion graphics conveying power and precision.",
                    "dur": 4.0,
                },
                {
                    "title": "Lead the Future",
                    "screen": f"{cta}",
                    "voice": f"The future belongs to those who act. Discover {brand} today.",
                    "vis": "Minimalist premium typography on deep obsidian backdrop with glowing CTA.",
                    "dur": 4.5,
                },
            ],
        }

        scene_defs = templates.get(archetype, templates["saas_product_ad"])
        if target_scenes < len(scene_defs):
            scene_defs = scene_defs[:target_scenes - 1] + [scene_defs[-1]]

        scenes: List[Dict[str, Any]] = []
        for idx, s in enumerate(scene_defs):
            scene_id = f"scene_{idx + 1}_{uuid.uuid4().hex[:6]}"
            is_last = idx == len(scene_defs) - 1

            assigned_media = []
            source_type = "built_in_gradient"
            if idx < len(user_clips):
                assigned_media.append(user_clips[idx])
                source_type = "user_video_clip"
            elif idx < len(user_images):
                assigned_media.append(user_images[idx])
                source_type = "user_screenshot"

            scenes.append({
                "id": scene_id,
                "scene_title": s["title"],
                "on_screen_text": s["screen"],
                "voice_over_narration": s["voice"],
                "subtitle_text": s["voice"],
                "visual_description": s["vis"],
                "visual_generation_prompt": f"{s['vis']}, high quality render, {brand_color} accents, 4k",
                "visual_source_type": source_type,
                "visual_asset_paths": assigned_media,
                "duration_seconds": s["dur"],
                "transition": "fade" if idx > 0 else "cut",
                "call_to_action": cta if is_last else "",
            })

        return scenes

    def regenerate_field(
        self,
        scene: Dict[str, Any],
        field_type: str,
        brand_name: str = "",
        brand_color: str = "#2563EB",
    ) -> Dict[str, Any]:
        """
        Regenerates only the requested field or scope, preserving all other fields intact.
        Guarantees that narration changes do NOT alter visuals, and vice-versa.
        """
        updated = dict(scene)
        scene_id = scene.get("id", f"scene_{uuid.uuid4().hex[:6]}")
        updated["id"] = scene_id
        brand = brand_name or "AppGrowth"

        if field_type == "visual_only":
            updated["visual_description"] = f"Fresh visual styling for {scene.get('scene_title', 'Feature')}: high-contrast modern card with ambient depth."
            updated["visual_generation_prompt"] = f"Modern tech product design, soft gradients, clean lighting, brand tone {brand_color}"
            # Narration, captions, title, and CTA are untouched

        elif field_type == "narration_only":
            cur_title = scene.get("scene_title", "Feature")
            updated["voice_over_narration"] = f"With {brand}, {cur_title.lower()} is effortless and reliable every single day."
            updated["subtitle_text"] = updated["voice_over_narration"]
            # Visual description, visual assets, on-screen text, and title are untouched

        elif field_type == "on_screen_text_only":
            cur_voice = scene.get("voice_over_narration", "")
            words = cur_voice.split()
            if len(words) >= 4:
                updated["on_screen_text"] = " ".join(words[:4]).title()
            else:
                updated["on_screen_text"] = f"{brand} Advantage"
            # Narration and visuals are untouched

        elif field_type == "scene_only":
            updated["scene_title"] = f"Enhanced {brand} Capability"
            updated["on_screen_text"] = f"Work Smarter with {brand}"
            updated["voice_over_narration"] = f"Unlock next-level efficiency with {brand}'s dedicated capabilities."
            updated["subtitle_text"] = updated["voice_over_narration"]
            updated["visual_description"] = "Dynamic feature highlight with interactive motion accents."

        return updated
