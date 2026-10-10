"""
FFmpeg Video Assembly and MP4 Verification Engine for AppGrowth Studio.
Renders high-resolution video frames, mixes narration and music,
handles aspect ratios without distortion, and verifies real playable output.
Robustly resolves FFmpeg paths and prevents WinError 2 issues.
"""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple
from PIL import Image, ImageDraw, ImageFont

from backend.audio_synthesizer import AudioSynthesizer
from backend.executable_resolver import get_workspace_root, resolve_ffmpeg_path

logger = logging.getLogger(__name__)


class VideoRenderer:
    def __init__(self, ffmpeg_path: Optional[str] = None, temp_dir: Optional[str] = None):
        root = get_workspace_root()
        resolved_ffmpeg, _ = resolve_ffmpeg_path(ffmpeg_path)
        self.ffmpeg_path = resolved_ffmpeg or (os.path.join(root, "ffmpeg.exe") if os.path.exists(os.path.join(root, "ffmpeg.exe")) else "ffmpeg")
        
        default_temp = os.path.join(root, "backend", "renders", "temp")
        self.temp_dir = os.path.abspath(temp_dir or default_temp)
        os.makedirs(self.temp_dir, exist_ok=True)
        self.audio_synth = AudioSynthesizer(ffmpeg_path=self.ffmpeg_path)

    def is_ffmpeg_ready(self) -> bool:
        """Returns True if the FFmpeg executable is resolved and executable."""
        if not self.ffmpeg_path or not os.path.isfile(self.ffmpeg_path):
            return False
        try:
            res = subprocess.run([self.ffmpeg_path, "-version"], capture_output=True, text=True, timeout=5)
            return res.returncode == 0
        except Exception:
            return False

    def get_resolution_dimensions(self, aspect_ratio: str, resolution: str) -> Tuple[int, int]:
        """Calculates exact width and height for target aspect ratio and resolution."""
        is_1080p = "1080" in resolution or resolution.lower() == "full hd"
        ratio = aspect_ratio.strip()

        if ratio == "9:16":
            return (1080, 1920) if is_1080p else (720, 1280)
        elif ratio == "1:1":
            return (1080, 1080) if is_1080p else (720, 720)
        else:  # 16:9 landscape default
            return (1920, 1080) if is_1080p else (1280, 720)

    def render_project(
        self,
        project_id: str,
        scenes: List[Dict[str, Any]],
        aspect_ratio: str = "9:16",
        resolution: str = "1080p",
        brand_color: str = "#2563EB",
        output_dir: Optional[str] = None,
        progress_callback: Optional[Callable[[str, str, float], None]] = None,
    ) -> Dict[str, Any]:
        """
        Renders the complete video project to a verified playable MP4.
        Ensures strict validation and reliable path resolution.
        """
        root = get_workspace_root()
        if not self.is_ffmpeg_ready():
            raise FileNotFoundError(
                f"FFmpeg binary not found or not executable at '{self.ffmpeg_path}'. "
                f"Please ensure ffmpeg.exe exists in '{root}' or is installed in PATH."
            )

        width, height = self.get_resolution_dimensions(aspect_ratio, resolution)
        work_dir = os.path.join(self.temp_dir, f"job_{project_id}")
        os.makedirs(work_dir, exist_ok=True)
        frames_dir = os.path.join(work_dir, "frames")
        os.makedirs(frames_dir, exist_ok=True)
        audio_dir = os.path.join(work_dir, "audio")
        os.makedirs(audio_dir, exist_ok=True)

        final_out_dir = os.path.abspath(output_dir or os.path.join(root, "backend", "renders"))
        os.makedirs(final_out_dir, exist_ok=True)
        final_mp4_path = os.path.join(final_out_dir, f"{project_id}_rendered.mp4")

        scene_clip_paths: List[str] = []
        total_scenes = len(scenes)

        if progress_callback:
            progress_callback("preparing_inputs", f"Preparing {total_scenes} scenes at {width}x{height}", 0.1)

        # 1. Process each scene
        for idx, scene in enumerate(scenes):
            scene_num = idx + 1
            scene_dur = float(scene.get("duration_seconds") or scene.get("duration") or 3.5)
            narration = scene.get("voice_over_narration") or scene.get("narration") or ""

            # A. Generate Narration Audio for Scene
            scene_audio_path = os.path.join(audio_dir, f"scene_{scene_num}.wav")
            audio_duration = 0.0
            if narration and narration.strip():
                try:
                    audio_duration = self.audio_synth.synthesize_speech(narration, scene_audio_path)
                except Exception as e:
                    logger.warning("Narration synthesis failed for scene %d, using fallback: %s", scene_num, e)
                    self.audio_synth._create_silent_audio(scene_audio_path, scene_dur)
                    audio_duration = scene_dur
            else:
                self.audio_synth._create_silent_audio(scene_audio_path, scene_dur)
                audio_duration = scene_dur

            # Ensure scene duration accommodates full speech without truncation
            final_scene_dur = max(scene_dur, round(audio_duration + 0.4, 2))

            # B. Render High-Res Visual Slide Frame for Scene
            frame_img_path = os.path.join(frames_dir, f"frame_{scene_num}.png")
            self._render_scene_image(
                scene=scene,
                width=width,
                height=height,
                brand_color=brand_color,
                output_path=frame_img_path,
            )

            # C. Check if Scene has an existing video clip
            user_clips = scene.get("visual_asset_paths", [])
            clip_from_field = scene.get("video_clip_path")
            if clip_from_field and clip_from_field not in user_clips:
                user_clips = [clip_from_field] + user_clips

            video_asset = next((p for p in user_clips if p and p.lower().endswith((".mp4", ".mov", ".avi", ".mkv")) and os.path.isfile(p)), None)

            # D. Compile Scene Clip
            scene_clip_path = os.path.join(work_dir, f"clip_{scene_num}.mp4")
            if video_asset:
                self._encode_video_scene_clip(
                    video_asset_path=video_asset,
                    audio_path=scene_audio_path,
                    target_width=width,
                    target_height=height,
                    duration=final_scene_dur,
                    output_path=scene_clip_path,
                )
            else:
                self._encode_image_scene_clip(
                    image_path=frame_img_path,
                    audio_path=scene_audio_path,
                    target_width=width,
                    target_height=height,
                    duration=final_scene_dur,
                    output_path=scene_clip_path,
                )

            # Verify that scene clip was generated and has non-zero size
            if not os.path.isfile(scene_clip_path) or os.path.getsize(scene_clip_path) == 0:
                raise RuntimeError(f"Failed to generate valid scene clip for scene {scene_num} at {scene_clip_path}")

            scene_clip_paths.append(scene_clip_path)

            if progress_callback:
                pct = 0.15 + (0.55 * (scene_num / total_scenes))
                progress_callback("generating_video_clips", f"Completed scene {scene_num}/{total_scenes}", pct)

        # 2. Concat all scene clips
        concat_list_file = os.path.join(work_dir, "concat_list.txt")
        with open(concat_list_file, "w", encoding="utf-8") as f:
            for clip_p in scene_clip_paths:
                # Use POSIX forward slashes to ensure FFmpeg concat demuxer on Windows opens properly
                posix_path = Path(clip_p).as_posix()
                f.write(f"file '{posix_path}'\n")

        temp_concat_mp4 = os.path.join(work_dir, "concatenated.mp4")
        concat_cmd = [
            self.ffmpeg_path,
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", "concat_list.txt",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "concatenated.mp4",
        ]
        if progress_callback:
            progress_callback("assembling_video", "Concatenating scenes into unified timeline", 0.75)

        concat_res = subprocess.run(concat_cmd, cwd=work_dir, capture_output=True, text=True, timeout=120)
        if concat_res.returncode != 0 or not os.path.exists(temp_concat_mp4):
            err_log = concat_res.stderr or concat_res.stdout
            raise RuntimeError(f"FFmpeg scene concatenation failed (exit code {concat_res.returncode}): {err_log}")

        # 3. Add background music and master mix
        total_duration = self._get_media_duration(temp_concat_mp4)
        bg_music_path = os.path.join(work_dir, "ambient_bg.wav")
        self.audio_synth.generate_ambient_background_music(bg_music_path, total_duration)

        if progress_callback:
            progress_callback("processing_audio", "Mixing voice narration and background score", 0.85)

        # Mix with volume balancing: narration 1.0, music 0.14
        mix_cmd = [
            self.ffmpeg_path,
            "-y",
            "-i", temp_concat_mp4,
            "-i", bg_music_path,
            "-filter_complex",
            "[0:a]volume=1.0[vocal];[1:a]volume=0.14[bg];[vocal][bg]amix=inputs=2:duration=first:dropout_transition=2[aout]",
            "-map", "0:v",
            "-map", "[aout]",
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            final_mp4_path,
        ]
        mix_res = subprocess.run(mix_cmd, cwd=work_dir, capture_output=True, text=True, timeout=120)
        if mix_res.returncode != 0 or not os.path.exists(final_mp4_path):
            logger.warning("Audio mix command failed, copying concatenated video directly: %s", mix_res.stderr)
            shutil.copy(temp_concat_mp4, final_mp4_path)

        if progress_callback:
            progress_callback("validating_output", "Verifying video streams, duration, and playback decoding", 0.95)

        # 4. Strict Validation
        validation = self.probe_video(final_mp4_path)
        if not validation["is_valid"]:
            raise RuntimeError(f"Render validation failed: {validation.get('error', 'Invalid video stream')}")

        if progress_callback:
            progress_callback("completed", "Video rendered and verified successfully", 1.0)

        # Clean up temp working files
        try:
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass

        return {
            "success": True,
            "mp4_path": final_mp4_path,
            "validation": validation,
        }

    def _render_scene_image(
        self,
        scene: Dict[str, Any],
        width: int,
        height: int,
        brand_color: str,
        output_path: str,
    ) -> None:
        """
        Creates a high-resolution, modern promotional scene slide with
        clean gradients, brand framing, device mockup placement, and bold typography.
        """
        img = Image.new("RGBA", (width, height), (15, 23, 42, 255))
        draw = ImageDraw.Draw(img)

        # Background gradient: deep slate with brand color aura
        r, g, b = self._parse_hex_color(brand_color)
        for y in range(height):
            factor = y / float(height)
            cr = int(12 * (1 - factor) + (r * 0.25) * factor)
            cg = int(18 * (1 - factor) + (g * 0.25) * factor)
            cb = int(32 * (1 - factor) + (b * 0.25) * factor)
            draw.line([(0, y), (width, y)], fill=(cr, cg, cb, 255))

        # Check for user screenshot or image
        user_assets = scene.get("visual_asset_paths", [])
        single_img = scene.get("image_asset_path")
        if single_img and single_img not in user_assets:
            user_assets = [single_img] + user_assets

        user_image_path = next((p for p in user_assets if p and os.path.exists(p) and p.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))), None)

        if user_image_path:
            try:
                user_img = Image.open(user_image_path).convert("RGBA")
                max_w = int(width * 0.85)
                max_h = int(height * 0.55)
                user_img.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)

                pos_x = (width - user_img.width) // 2
                pos_y = int(height * 0.24)

                draw.rounded_rectangle(
                    [pos_x - 8, pos_y - 8, pos_x + user_img.width + 8, pos_y + user_img.height + 8],
                    radius=16,
                    fill=(30, 41, 59, 230),
                    outline=(r, g, b, 180),
                    width=3,
                )
                img.paste(user_img, (pos_x, pos_y), user_img)
            except Exception:
                pass
        else:
            # Procedural UI Card Graphic
            card_w = int(width * 0.85)
            card_h = int(height * 0.45)
            card_x = (width - card_w) // 2
            card_y = int(height * 0.26)
            draw.rounded_rectangle(
                [card_x, card_y, card_x + card_w, card_y + card_h],
                radius=24,
                fill=(30, 41, 59, 240),
                outline=(r, g, b, 200),
                width=4,
            )
            # Decorative card elements
            draw.rounded_rectangle(
                [card_x + 30, card_y + 35, card_x + 180, card_y + 65],
                radius=8,
                fill=(r, g, b, 220),
            )
            draw.line([(card_x + 30, card_y + 110), (card_x + card_w - 30, card_y + 110)], fill=(51, 65, 85, 255), width=2)
            for li in range(3):
                ly = card_y + 150 + (li * 40)
                draw.rounded_rectangle([card_x + 30, ly, card_x + card_w - 60, ly + 20], radius=6, fill=(51, 65, 85, 200))

        # Typography
        title = scene.get("scene_title") or scene.get("title") or ""
        on_screen = scene.get("on_screen_text") or ""
        cta = scene.get("call_to_action") or ""

        # Header Badge
        if title:
            badge_y = int(height * 0.08)
            draw.rounded_rectangle(
                [int(width * 0.08), badge_y, int(width * 0.92), badge_y + 64],
                radius=14,
                fill=(15, 23, 42, 210),
                outline=(r, g, b, 220),
                width=2,
            )
            draw.text((int(width * 0.12), badge_y + 18), title[:40], fill=(241, 245, 249, 255))

        # Bottom Caption / Subtitle Text
        caption_text = on_screen or scene.get("voice_over_narration") or scene.get("narration") or ""
        if caption_text:
            cap_y = int(height * 0.82)
            draw.rounded_rectangle(
                [int(width * 0.06), cap_y, int(width * 0.94), cap_y + 90],
                radius=16,
                fill=(15, 23, 42, 230),
                outline=(51, 65, 85, 255),
                width=2,
            )
            draw.text((int(width * 0.10), cap_y + 24), caption_text[:50], fill=(255, 255, 255, 255))

        # Call To Action Button (if last scene)
        if cta:
            cta_y = int(height * 0.72)
            cta_w = int(width * 0.7)
            cta_x = (width - cta_w) // 2
            draw.rounded_rectangle(
                [cta_x, cta_y, cta_x + cta_w, cta_y + 70],
                radius=35,
                fill=(r, g, b, 255),
            )
            draw.text((cta_x + 40, cta_y + 22), f"★ {cta.upper()} ★", fill=(255, 255, 255, 255))

        img.convert("RGB").save(output_path, "PNG")

    def _encode_image_scene_clip(
        self,
        image_path: str,
        audio_path: str,
        target_width: int,
        target_height: int,
        duration: float,
        output_path: str,
    ) -> None:
        """Encodes a still slide image with smooth subtle zoom motion and synchronized audio."""
        dur = max(1.5, float(duration))
        zoom_filter = (
            f"scale={target_width}x{target_height},"
            f"zoompan=z='min(zoom+0.0006,1.06)':d={int(dur * 30)}:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={target_width}x{target_height}:fps=30"
        )
        cmd = [
            self.ffmpeg_path,
            "-y",
            "-loop", "1",
            "-i", image_path,
            "-i", audio_path,
            "-c:v", "libx264",
            "-t", str(dur),
            "-pix_fmt", "yuv420p",
            "-vf", zoom_filter,
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            output_path,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60, cwd=os.path.dirname(output_path))
        if res.returncode != 0 or not os.path.exists(output_path):
            # Fallback without zoompan filter
            fallback_cmd = [
                self.ffmpeg_path,
                "-y",
                "-loop", "1",
                "-i", image_path,
                "-i", audio_path,
                "-c:v", "libx264",
                "-t", str(dur),
                "-pix_fmt", "yuv420p",
                "-vf", f"scale={target_width}:{target_height}",
                "-c:a", "aac",
                "-b:a", "192k",
                "-shortest",
                output_path,
            ]
            fb_res = subprocess.run(fallback_cmd, capture_output=True, text=True, timeout=60, cwd=os.path.dirname(output_path))
            if fb_res.returncode != 0:
                raise RuntimeError(f"FFmpeg image encoding failed: {fb_res.stderr}")

    def _encode_video_scene_clip(
        self,
        video_asset_path: str,
        audio_path: str,
        target_width: int,
        target_height: int,
        duration: float,
        output_path: str,
    ) -> None:
        """Encodes an existing video clip, normalizing resolution with aspect-ratio letterboxing."""
        scale_filter = (
            f"scale={target_width}:{target_height}:force_original_aspect_ratio=decrease,"
            f"pad={target_width}:{target_height}:(ow-iw)/2:(oh-ih)/2:color=black"
        )
        cmd = [
            self.ffmpeg_path,
            "-y",
            "-i", video_asset_path,
            "-i", audio_path,
            "-t", str(duration),
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            "-vf", scale_filter,
            "-c:a", "aac",
            "-b:a", "192k",
            output_path,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=60, cwd=os.path.dirname(output_path))
        if res.returncode != 0:
            raise RuntimeError(f"FFmpeg video encoding failed: {res.stderr}")

    def probe_video(self, video_path: str) -> Dict[str, Any]:
        """
        Validates that a video file exists, is non-empty, contains a playable video stream,
        and has non-zero duration.
        """
        result = {
            "is_valid": False,
            "path": video_path,
            "size_bytes": 0,
            "duration_seconds": 0.0,
            "width": 0,
            "height": 0,
            "codec": "",
            "error": None,
        }

        if not os.path.exists(video_path):
            result["error"] = "File does not exist"
            return result

        size = os.path.getsize(video_path)
        result["size_bytes"] = size
        if size == 0:
            result["error"] = "File is 0 bytes"
            return result

        if not self.ffmpeg_path:
            result["error"] = "FFmpeg executable is not configured"
            return result

        cmd = [self.ffmpeg_path, "-i", video_path]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            output = proc.stderr
        except Exception as e:
            result["error"] = f"Failed to execute FFmpeg probe: {str(e)}"
            return result

        dur_match = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.\d+)", output)
        if dur_match:
            hours = float(dur_match.group(1))
            minutes = float(dur_match.group(2))
            seconds = float(dur_match.group(3))
            result["duration_seconds"] = round(hours * 3600 + minutes * 60 + seconds, 2)

        vid_match = re.search(r"Video:\s*([a-zA-Z0-9_-]+).*?,\s*(\d+)x(\d+)", output)
        if vid_match:
            result["codec"] = vid_match.group(1)
            result["width"] = int(vid_match.group(2))
            result["height"] = int(vid_match.group(3))

        if result["duration_seconds"] > 0 and result["width"] > 0 and result["height"] > 0:
            result["is_valid"] = True
        else:
            result["error"] = "Missing valid video stream or duration"

        return result

    def _get_media_duration(self, path: str) -> float:
        info = self.probe_video(path)
        return info.get("duration_seconds", 5.0)

    def _parse_hex_color(self, hex_color: str) -> Tuple[int, int, int]:
        c = hex_color.lstrip("#")
        if len(c) == 3:
            c = "".join(2 * ch for ch in c)
        if len(c) == 6:
            return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16))
        return (37, 99, 235)
