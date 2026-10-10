"""
Executable Resolver and System Environment Detector for AppGrowth Studio.
Reliably discovers and validates Python interpreters, FFmpeg, FFprobe,
PowerShell, and GPU hardware devices across Windows environments without
assuming binaries exist in global PATH.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def get_workspace_root() -> str:
    """Returns the absolute path to the project root directory."""
    current = os.path.dirname(os.path.abspath(__file__))
    parent = os.path.abspath(os.path.join(current, ".."))
    # Check if parent contains app files or ffmpeg.exe
    if os.path.exists(os.path.join(parent, "pubspec.yaml")) or os.path.exists(os.path.join(parent, "ffmpeg.exe")):
        return parent
    return parent


def resolve_ffmpeg_path(custom_path: Optional[str] = None) -> Tuple[Optional[str], Optional[str]]:
    """
    Finds a verified, working ffmpeg.exe binary.
    Returns (executable_path, version_string) or (None, None).
    """
    root = get_workspace_root()
    candidates: List[str] = []

    if custom_path and custom_path.strip():
        candidates.append(os.path.abspath(custom_path.strip()))

    # 1. Project root / App directory
    candidates.append(os.path.join(root, "ffmpeg.exe"))
    candidates.append(os.path.join(root, "backend", "ffmpeg.exe"))

    # 2. System PATH via shutil.which
    which_ffmpeg = shutil.which("ffmpeg.exe") or shutil.which("ffmpeg")
    if which_ffmpeg:
        candidates.append(os.path.abspath(which_ffmpeg))

    # 3. Common Windows install locations
    local_app_data = os.environ.get("LOCALAPPDATA", "")
    if local_app_data:
        candidates.append(os.path.join(local_app_data, "Microsoft", "WinGet", "Links", "ffmpeg.exe"))
        candidates.append(os.path.join(local_app_data, "Aloha Mobile", "Aloha", "Application", "4.9.0.0", "ffmpeg.exe"))
    app_data = os.environ.get("APPDATA", "")
    if app_data:
        candidates.append(os.path.join(app_data, "dolphin_anty", "browser", "469", "resources", "ffmpeg.exe"))

    candidates.extend([
        r"C:\ffmpeg\bin\ffmpeg.exe",
        r"C:\ProgramData\chocolatey\bin\ffmpeg.exe",
        r"C:\tools\ffmpeg\bin\ffmpeg.exe",
    ])

    for path in candidates:
        if path and os.path.isfile(path):
            try:
                # Test execution
                res = subprocess.run(
                    [path, "-version"],
                    capture_output=True,
                    text=True,
                    timeout=8,
                    cwd=root,
                )
                if res.returncode == 0 and "ffmpeg version" in res.stdout:
                    version_line = res.stdout.splitlines()[0]
                    return os.path.abspath(path), version_line
            except Exception:
                continue

    return None, None


def resolve_ffprobe_path(custom_path: Optional[str] = None) -> Tuple[Optional[str], Optional[str]]:
    """Finds a verified, working ffprobe.exe binary."""
    root = get_workspace_root()
    candidates: List[str] = []

    if custom_path and custom_path.strip():
        candidates.append(os.path.abspath(custom_path.strip()))

    candidates.append(os.path.join(root, "ffprobe.exe"))
    candidates.append(os.path.join(root, "backend", "ffprobe.exe"))

    # Check alongside verified ffmpeg
    ffmpeg_exe, _ = resolve_ffmpeg_path()
    if ffmpeg_exe:
        sibling = os.path.join(os.path.dirname(ffmpeg_exe), "ffprobe.exe")
        candidates.append(sibling)

    which_probe = shutil.which("ffprobe.exe") or shutil.which("ffprobe")
    if which_probe:
        candidates.append(os.path.abspath(which_probe))

    for path in candidates:
        if path and os.path.isfile(path):
            try:
                res = subprocess.run([path, "-version"], capture_output=True, text=True, timeout=8, cwd=root)
                if res.returncode == 0:
                    version_line = res.stdout.splitlines()[0]
                    return os.path.abspath(path), version_line
            except Exception:
                continue

    return None, None


def resolve_python_path(custom_path: Optional[str] = None) -> Tuple[Optional[str], Optional[str]]:
    """
    Finds a verified, working python.exe or py.exe interpreter.
    Ignores non-functional WindowsApps stub shortcuts.
    """
    candidates: List[str] = []

    if custom_path and custom_path.strip():
        candidates.append(os.path.abspath(custom_path.strip()))

    # Currently running interpreter
    if sys.executable:
        candidates.append(sys.executable)

    # Python launcher py.exe
    py_launcher = shutil.which("py.exe") or shutil.which("py")
    if py_launcher:
        try:
            # Query py -0p for the default interpreter path
            res = subprocess.run([py_launcher, "-0p"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    parts = line.strip().split()
                    if parts and os.path.isfile(parts[-1]):
                        candidates.append(parts[-1])
        except Exception:
            pass

    # Standard Windows install locations
    local_programs = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python")
    if os.path.exists(local_programs):
        for entry in sorted(os.listdir(local_programs), reverse=True):
            sub = os.path.join(local_programs, entry, "python.exe")
            if os.path.isfile(sub):
                candidates.append(sub)

    # Program files
    for root_dir in [r"C:\Program Files\Python*", r"C:\Python*"]:
        import glob
        for matched in glob.glob(root_dir):
            exe = os.path.join(matched, "python.exe")
            if os.path.isfile(exe):
                candidates.append(exe)

    for path in candidates:
        if not path or not os.path.isfile(path):
            continue
        # Avoid Microsoft WindowsApps redirection stub
        if "WindowsApps" in path:
            continue
        try:
            res = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                ver = (res.stdout or res.stderr).strip()
                return os.path.abspath(path), ver
        except Exception:
            continue

    return None, None


def detect_gpu_hardware() -> Dict[str, Any]:
    """
    Inspects system GPUs, detects NVIDIA CUDA availability, VRAM in GB,
    and returns a structured readiness assessment.
    """
    result: Dict[str, Any] = {
        "has_cuda": False,
        "gpu_count": 0,
        "gpus": [],
        "total_vram_gb": 0.0,
        "recommended_for_local_ai": False,
        "cuda_version": None,
        "raw_controllers": [],
    }

    # 1. Check NVIDIA via nvidia-smi
    smi = shutil.which("nvidia-smi.exe") or shutil.which("nvidia-smi")
    if smi:
        try:
            cmd = [smi, "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader,nounits"]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]
                for l in lines:
                    parts = [p.strip() for p in l.split(",")]
                    if len(parts) >= 2:
                        name = parts[0]
                        vram_mb = float(parts[1]) if parts[1].replace(".", "").isdigit() else 0.0
                        driver = parts[2] if len(parts) > 2 else "unknown"
                        vram_gb = round(vram_mb / 1024.0, 2)
                        result["gpus"].append({
                            "name": name,
                            "vram_gb": vram_gb,
                            "driver": driver,
                            "type": "NVIDIA CUDA",
                        })
                        result["total_vram_gb"] += vram_gb
                if result["gpus"]:
                    result["has_cuda"] = True
                    result["gpu_count"] = len(result["gpus"])
                    result["recommended_for_local_ai"] = result["total_vram_gb"] >= 6.0
                    return result
        except Exception:
            pass

    # 2. Check Windows WMI / CIM for all video controllers
    try:
        ps_cmd = (
            "Get-CimInstance Win32_VideoController | "
            "Select-Object Name, AdapterRAM, DriverVersion | "
            "ConvertTo-Json -Compress"
        )
        res = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
            capture_output=True,
            text=True,
            timeout=8,
        )
        if res.returncode == 0 and res.stdout.strip():
            import json
            data = json.loads(res.stdout)
            controllers = data if isinstance(data, list) else [data]
            for c in controllers:
                name = c.get("Name", "Unknown GPU")
                ram_bytes = c.get("AdapterRAM") or 0
                ram_gb = round(float(ram_bytes) / (1024.0 ** 3), 2)
                driver = c.get("DriverVersion", "Unknown")
                is_nvidia = "nvidia" in name.lower() or "geforce" in name.lower()
                is_intel = "intel" in name.lower()
                is_amd = "amd" in name.lower() or "radeon" in name.lower()

                gpu_type = "NVIDIA CUDA" if is_nvidia else ("AMD Radeon" if is_amd else ("Intel Integrated" if is_intel else "Generic GPU"))
                result["raw_controllers"].append({"name": name, "vram_gb": ram_gb, "driver": driver, "type": gpu_type})

                if is_nvidia:
                    result["has_cuda"] = True
                    result["gpus"].append({"name": name, "vram_gb": ram_gb, "driver": driver, "type": "NVIDIA CUDA"})
                    result["total_vram_gb"] += ram_gb

            result["gpu_count"] = len(result["raw_controllers"])
            result["recommended_for_local_ai"] = result["has_cuda"] and result["total_vram_gb"] >= 6.0
    except Exception:
        pass

    return result
