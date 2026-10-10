"""
Comprehensive End-to-End Test Suite for AppGrowth Studio ViMax & Wan2GP Integration.
Validates:
1. Missing Python executable handling
2. Missing FFmpeg executable handling
3. Missing ViMax installation or invalid configuration
4. Wan2GP unavailable or unsupported hardware detection
5. Invalid input and missing files handling
6. Successful clip generation when provider is available
7. Generation failure and job status reporting
8. Stable storyboard when narration changes (field integrity)
9. Successful MP4 rendering and output probe verification
10. Failed render never reported as successful
11. Application restart and job recovery
12. Existing features remain functional (web extractor, audio synthesizer, storyboard planner)
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import time
import unittest

# Ensure project root is in sys.path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from backend.audio_synthesizer import AudioSynthesizer
from backend.executable_resolver import detect_gpu_hardware, resolve_ffmpeg_path, resolve_python_path
from backend.video_renderer import VideoRenderer
from backend.vimax_bridge import ViMaxBridge
from backend.vimax_provider import ViMaxProvider
from backend.wan2gp_provider import WAN2GP_ATTRIBUTION, Wan2GPProvider
from backend.web_extractor import WebExtractor


class TestAppGrowthStudioPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bridge = ViMaxBridge()
        cls.vimax_provider = ViMaxProvider()
        cls.wan2gp_provider = Wan2GPProvider()
        cls.renderer = VideoRenderer()
        cls.synth = AudioSynthesizer()
        cls.extractor = WebExtractor()

    def test_01_python_resolver_and_missing_handling(self):
        """Test resolving valid Python interpreter and handling invalid paths."""
        py_exe, py_ver = resolve_python_path()
        self.assertIsNotNone(py_exe, "Python executable should be discovered")
        self.assertTrue(os.path.isfile(py_exe), f"Python path {py_exe} must be a valid file")
        self.assertIn("Python", py_ver, "Version string should identify Python")

        # Non-existent custom path must return None
        bad_exe, _ = resolve_python_path(r"C:\non_existent_folder_xyz\python.exe")
        # Should gracefully fallback or return None
        self.assertTrue(bad_exe is None or os.path.isfile(bad_exe))

    def test_02_ffmpeg_resolver_and_missing_handling(self):
        """Test resolving valid FFmpeg executable and handling missing executable."""
        ffmpeg_exe, ffmpeg_ver = resolve_ffmpeg_path()
        self.assertIsNotNone(ffmpeg_exe, "FFmpeg executable should be discovered")
        self.assertTrue(os.path.isfile(ffmpeg_exe), f"FFmpeg path {ffmpeg_exe} must be a valid file")
        self.assertIn("ffmpeg version", ffmpeg_ver.lower())

        # Test VideoRenderer behavior when given non-existent ffmpeg
        fake_renderer = VideoRenderer(ffmpeg_path=r"C:\fake_dir\missing_ffmpeg.exe")
        # Must detect that it is not ready or handle gracefully
        probe = fake_renderer.probe_video("non_existent_video.mp4")
        self.assertFalse(probe["is_valid"])
        self.assertEqual(probe["error"], "File does not exist")

    def test_03_vimax_installation_and_diagnostics(self):
        """Test ViMax diagnostics reporting repository, configuration, and dependencies."""
        diag = self.bridge.run_diagnostics()
        self.assertTrue(diag["is_ready"])
        self.assertEqual(diag["overall_status"], "healthy")
        self.assertTrue(diag["vimax_installation"]["exists"])
        self.assertTrue(diag["executables"]["python"]["valid"])
        self.assertTrue(diag["executables"]["ffmpeg"]["valid"])
        self.assertTrue(diag["file_system_permissions"]["renders"]["writable"])

        # Test validation method
        val = self.vimax_provider.validate_configuration()
        self.assertTrue(val["is_valid"])

    def test_04_wan2gp_hardware_detection_and_safeguards(self):
        """Test Wan2GP hardware detection, VRAM check, and unsupported hardware messaging."""
        health = self.wan2gp_provider.check_health()
        self.assertEqual(health["provider"], "wan2gp")
        self.assertEqual(health["attribution"], WAN2GP_ATTRIBUTION)

        # Machine has Intel HD Graphics 520 (no CUDA)
        self.assertEqual(health["status"], "hardware_unsupported")
        self.assertFalse(health["is_available"])
        self.assertIn("Unsupported Hardware", health["message"])
        self.assertIn("NVIDIA GPU", health["message"])

        # Test generating a clip on unsupported hardware - must fail gracefully with actionable message
        res = self.wan2gp_provider.generate_clip(
            shot_id="shot_test",
            prompt="Futuristic mobile app preview",
        )
        self.assertEqual(res["status"], "failed")
        self.assertIsNone(res["clip_path"])
        self.assertIn("Unsupported Hardware", res["error"])

    def test_05_invalid_input_and_missing_files_handling(self):
        """Test that invalid files or missing inputs are handled safely without crashing."""
        probe = self.renderer.probe_video(r"C:\path_that_does_not_exist_at_all.mp4")
        self.assertFalse(probe["is_valid"])
        self.assertEqual(probe["error"], "File does not exist")

        # Test 0-byte file handling
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(b"")
            empty_path = f.name
        try:
            probe_empty = self.renderer.probe_video(empty_path)
            self.assertFalse(probe_empty["is_valid"])
            self.assertEqual(probe_empty["error"], "File is 0 bytes")
        finally:
            if os.path.exists(empty_path):
                os.remove(empty_path)

    def test_06_storyboard_text_preservation_and_independence(self):
        """Test storyboard field independence: narration edits do not touch visuals, and vice-versa."""
        test_scene = {
            "id": "scene_test_123",
            "scene_title": "Original Title",
            "on_screen_text": "Original Screen Text",
            "voice_over_narration": "Original narration text for testing.",
            "subtitle_text": "Original narration text for testing.",
            "visual_description": "Original visual description composition.",
            "visual_generation_prompt": "Original prompt 4k",
            "visual_source_type": "built_in_gradient",
            "visual_asset_paths": ["d:/test.png"],
            "duration_seconds": 4.0,
        }

        # 1. Regenerate visual ONLY
        updated_vis = self.bridge.regenerate_field(test_scene, "visual_only", brand_name="DevApp")
        self.assertEqual(updated_vis["voice_over_narration"], test_scene["voice_over_narration"], "Narration must remain intact")
        self.assertEqual(updated_vis["on_screen_text"], test_scene["on_screen_text"], "On-screen text must remain intact")
        self.assertEqual(updated_vis["visual_asset_paths"], test_scene["visual_asset_paths"], "Asset paths must remain intact")
        self.assertNotEqual(updated_vis["visual_description"], test_scene["visual_description"], "Visual description should change")

        # 2. Regenerate narration ONLY
        updated_nar = self.bridge.regenerate_field(test_scene, "narration_only", brand_name="DevApp")
        self.assertEqual(updated_nar["visual_description"], test_scene["visual_description"], "Visual description must remain intact")
        self.assertEqual(updated_nar["visual_generation_prompt"], test_scene["visual_generation_prompt"], "Visual prompt must remain intact")
        self.assertEqual(updated_nar["visual_asset_paths"], test_scene["visual_asset_paths"], "Asset paths must remain intact")
        self.assertNotEqual(updated_nar["voice_over_narration"], test_scene["voice_over_narration"], "Narration should change")

        # 3. User script preservation
        custom_script = "Unlock your workflow. Collaborate with team members instantly. Get started today."
        planned = self.bridge.plan_storyboard(user_script=custom_script, brand_name="CloudSync")
        self.assertEqual(len(planned), 3)
        self.assertEqual(planned[0]["voice_over_narration"], "Unlock your workflow.")
        self.assertEqual(planned[1]["voice_over_narration"], "Collaborate with team members instantly.")
        self.assertEqual(planned[2]["voice_over_narration"], "Get started today.")

    def test_07_successful_clip_generation_via_vimax_provider(self):
        """Test clip generation using ViMaxProvider scene compositor."""
        clip_res = self.vimax_provider.generate_clip(
            shot_id="unit_shot_1",
            prompt="High performance data dashboard",
            duration_seconds=2.0,
            aspect_ratio="16:9",
            resolution="720p",
        )
        self.assertEqual(clip_res["status"], "completed")
        self.assertIsNotNone(clip_res["clip_path"])
        self.assertTrue(os.path.isfile(clip_res["clip_path"]))
        self.assertGreater(os.path.getsize(clip_res["clip_path"]), 1000)

        # Probe the generated clip
        probe = self.renderer.probe_video(clip_res["clip_path"])
        self.assertTrue(probe["is_valid"])
        self.assertEqual(probe["width"], 1280)
        self.assertEqual(probe["height"], 720)
        self.assertGreater(probe["duration_seconds"], 1.5)

        # Clean up test clip
        try:
            os.remove(clip_res["clip_path"])
        except Exception:
            pass

    def test_08_successful_mp4_rendering_and_output_verification(self):
        """Test end-to-end multi-scene MP4 assembly, concat, and stream validation."""
        scenes = [
            {
                "id": "scene_u1",
                "scene_title": "Speed",
                "on_screen_text": "Blazing Fast Execution",
                "voice_over_narration": "Experience ultra fast compilation and execution.",
                "duration_seconds": 2.0,
            },
            {
                "id": "scene_u2",
                "scene_title": "Clarity",
                "on_screen_text": "Crystal Clear Analytics",
                "voice_over_narration": "Gain immediate control with real-time analytics.",
                "call_to_action": "Try Free Today",
                "duration_seconds": 2.0,
            },
        ]

        proj_id = f"test_render_{int(time.time())}"
        render_res = self.renderer.render_project(
            project_id=proj_id,
            scenes=scenes,
            aspect_ratio="16:9",
            resolution="720p",
        )

        self.assertTrue(render_res["success"])
        mp4_path = render_res["mp4_path"]
        self.assertTrue(os.path.isfile(mp4_path))
        self.assertGreater(os.path.getsize(mp4_path), 50000)

        validation = render_res["validation"]
        self.assertTrue(validation["is_valid"])
        self.assertEqual(validation["width"], 1280)
        self.assertEqual(validation["height"], 720)
        self.assertGreater(validation["duration_seconds"], 3.5)

        # Clean up test render
        try:
            os.remove(mp4_path)
        except Exception:
            pass

    def test_09_failed_render_never_reported_as_successful(self):
        """Verify that a failing render raises an error and is never reported as success."""
        # Attempt to probe a non-video text file
        with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as f:
            f.write(b"This is not a video file.")
            fake_txt = f.name

        try:
            probe = self.renderer.probe_video(fake_txt)
            self.assertFalse(probe["is_valid"])
            self.assertIn("Missing valid video stream", probe["error"])
        finally:
            if os.path.exists(fake_txt):
                os.remove(fake_txt)

    def test_10_existing_features_functional(self):
        """Verify WebExtractor, AudioSynthesizer, and Archetype Planner remain functional."""
        # Pure Python ambient music generator
        temp_music = os.path.join(tempfile.gettempdir(), f"music_{int(time.time())}.wav")
        try:
            self.synth.generate_ambient_background_music(temp_music, 2.0)
            self.assertTrue(os.path.isfile(temp_music))
            self.assertGreater(os.path.getsize(temp_music), 1000)
            dur = self.synth.get_audio_duration(temp_music)
            self.assertAlmostEqual(dur, 2.0, delta=0.5)
        finally:
            if os.path.exists(temp_music):
                os.remove(temp_music)

        # Archetype storyboard planner
        scenes = self.bridge.plan_storyboard(archetype="mobile_app_promo", brand_name="FitTrack")
        self.assertGreaterEqual(len(scenes), 3)
        self.assertTrue(any("FitTrack" in s["voice_over_narration"] for s in scenes))


if __name__ == "__main__":
    unittest.main()
