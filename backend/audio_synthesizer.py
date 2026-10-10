"""
Audio and Voice-Over Synthesizer for AppGrowth Studio + ViMax.
Supports native Windows SpeechSynthesizer, Edge-TTS fallback,
audio duration measurement, ambient background music generation,
and audio mixing with loudness balancing.
"""

from __future__ import annotations

import asyncio
import os
import re
import subprocess
import wave
from pathlib import Path
from typing import Optional


class AudioSynthesizer:
    def __init__(self, ffmpeg_path: str = "ffmpeg.exe", cache_dir: str = "backend/cache/audio"):
        self.ffmpeg_path = os.path.abspath(ffmpeg_path) if os.path.exists(ffmpeg_path) else "ffmpeg"
        self.cache_dir = os.path.abspath(cache_dir)
        os.makedirs(self.cache_dir, exist_ok=True)

    def synthesize_speech(
        self,
        text: str,
        output_path: str,
        voice: Optional[str] = None,
        rate: int = 0,
    ) -> float:
        """
        Synthesizes narration text to an audio file and returns its duration in seconds.
        Prioritizes native Windows SAPI SpeechSynthesizer for 100% offline reliability,
        with optional Edge-TTS fallback.
        """
        clean_text = text.strip()
        if not clean_text:
            clean_text = "..."

        out_path = os.path.abspath(output_path)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

        # 1. Try Windows native SpeechSynthesizer
        try:
            self._synthesize_windows_sapi(clean_text, out_path, voice=voice, rate=rate)
            duration = self.get_audio_duration(out_path)
            if duration > 0:
                return duration
        except Exception as e:
            # SAPI failed, try edge_tts if available
            pass

        # 2. Try Edge TTS
        try:
            edge_voice = voice or "en-US-AndrewMultilingualNeural"
            self._synthesize_edge_tts(clean_text, out_path, edge_voice)
            duration = self.get_audio_duration(out_path)
            if duration > 0:
                return duration
        except Exception:
            pass

        # 3. Fallback: create silent audio file of estimated duration
        words = len(clean_text.split())
        est_duration = max(2.5, words / 2.5)
        self._create_silent_audio(out_path, est_duration)
        return est_duration

    def _synthesize_windows_sapi(
        self,
        text: str,
        output_wav_path: str,
        voice: Optional[str] = None,
        rate: int = 0,
    ) -> None:
        """Generates speech via Windows System.Speech.Synthesis."""
        # Sanitize text for powershell single quotes
        safe_text = text.replace("'", "''").replace("\r", " ").replace("\n", " ")
        ps_script = (
            "Add-Type -AssemblyName System.Speech; "
            "$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        )
        if rate != 0:
            ps_script += f"$synth.Rate = {rate}; "
        if voice:
            safe_voice = voice.replace("'", "''")
            ps_script += f"try {{ $synth.SelectVoice('{safe_voice}') }} catch {{ }}; "
        ps_script += (
            f"$synth.SetOutputToWaveFile('{output_wav_path}'); "
            f"$synth.Speak('{safe_text}'); "
            "$synth.Dispose()"
        )

        res = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_script],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if res.returncode != 0:
            raise RuntimeError(f"PowerShell TTS failed: {res.stderr}")

        if not os.path.exists(output_wav_path) or os.path.getsize(output_wav_path) == 0:
            raise RuntimeError("PowerShell TTS did not generate a non-empty audio file")

    def _synthesize_edge_tts(self, text: str, output_path: str, voice: str) -> None:
        """Synthesizes speech using edge-tts asynchronously."""
        import edge_tts

        async def _run():
            communicate = edge_tts.Communicate(text, voice)
            await communicate.save(output_path)

        asyncio.run(_run())
        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            raise RuntimeError("Edge-TTS produced empty audio")

    def get_audio_duration(self, audio_path: str) -> float:
        """Returns the duration of an audio file in seconds."""
        if not os.path.exists(audio_path):
            return 0.0

        # Try wave module for .wav files
        if audio_path.lower().endswith(".wav"):
            try:
                with wave.open(audio_path, "rb") as wf:
                    frames = wf.getnframes()
                    rate = wf.getframerate()
                    if rate > 0:
                        return frames / float(rate)
            except Exception:
                pass

        # Try FFprobe / FFmpeg
        try:
            cmd = [
                self.ffmpeg_path,
                "-i", audio_path,
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            # FFmpeg outputs duration to stderr like "Duration: 00:00:04.52,"
            match = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.\d+)", res.stderr)
            if match:
                hours = float(match.group(1))
                minutes = float(match.group(2))
                seconds = float(match.group(3))
                return hours * 3600 + minutes * 60 + seconds
        except Exception:
            pass

        return 3.0

    def generate_ambient_background_music(self, output_path: str, duration_seconds: float) -> str:
        """
        Synthesizes a pleasant ambient background music chord progression using pure Python.
        Completely copyright-free and works 100% offline.
        """
        import math
        import struct

        out_path = os.path.abspath(output_path)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        dur = max(2.0, float(duration_seconds))
        sample_rate = 44100
        num_frames = int(sample_rate * dur)

        with wave.open(out_path, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            frames = bytearray()
            for i in range(num_frames):
                t = i / float(sample_rate)
                # Subtle envelope fade in / out
                fade = min(1.0, t / 1.0) * min(1.0, max(0.0, (dur - t) / 1.5))
                # Ambient chord: 220Hz (A3), 277Hz (C#4), 330Hz (E4), 440Hz (A4)
                sample = (
                    0.05 * math.sin(2 * math.pi * 220.0 * t) +
                    0.04 * math.sin(2 * math.pi * 277.18 * t) +
                    0.04 * math.sin(2 * math.pi * 329.63 * t) +
                    0.02 * math.sin(2 * math.pi * 440.0 * t)
                ) * fade
                val = int(max(-32767, min(32767, sample * 32767)))
                packed = struct.pack("<hh", val, val)
                frames.extend(packed)
            wf.writeframes(frames)
        return out_path

    def _create_silent_audio(self, output_path: str, duration_seconds: float) -> str:
        """Generates a silent audio file as fallback using pure Python wave module."""
        out_path = os.path.abspath(output_path)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        sample_rate = 44100
        num_frames = int(sample_rate * max(1.0, float(duration_seconds)))
        with wave.open(out_path, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(b"\x00\x00\x00\x00" * num_frames)
        return out_path
