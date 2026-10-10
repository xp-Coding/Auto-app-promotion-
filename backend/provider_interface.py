"""
Shared AI Video Generation Provider Interface for AppGrowth Studio.
Defines a standard lifecycle contract for local video clip generation providers
(ViMax, Wan2GP, and local composition fallback).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional


class VideoProviderInterface(ABC):
    """Abstract Base Class for Video Generation Providers."""

    @property
    @abstractmethod
    def provider_id(self) -> str:
        """Unique provider identifier (e.g. 'vimax', 'wan2gp')."""
        pass

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Human-readable provider name."""
        pass

    @abstractmethod
    def check_health(self) -> Dict[str, Any]:
        """
        Inspects provider readiness, hardware suitability, binary paths,
        and dependency availability.
        Returns:
            {
                "is_available": bool,
                "provider": str,
                "status": "ready" | "unavailable" | "hardware_unsupported",
                "message": str,
                "details": dict
            }
        """
        pass

    @abstractmethod
    def validate_configuration(self, config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Validates configuration settings, model paths, environments, and directories.
        Returns:
            {
                "is_valid": bool,
                "errors": list[str],
                "warnings": list[str],
                "resolved_config": dict
            }
        """
        pass

    @abstractmethod
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
        progress_callback: Optional[callable] = None,
    ) -> Dict[str, Any]:
        """
        Generates an individual video clip from a prompt and optional reference image.
        Returns:
            {
                "job_id": str,
                "status": "completed" | "failed" | "queued" | "running",
                "clip_path": str | None,
                "error": str | None,
                "duration_seconds": float,
                "provider": str
            }
        """
        pass

    @abstractmethod
    def get_job_status(self, job_id: str) -> Optional[Dict[str, Any]]:
        """Returns the current state, progress, and logs of an asynchronous generation job."""
        pass

    @abstractmethod
    def cancel_job(self, job_id: str) -> bool:
        """Cancels an ongoing generation job if supported."""
        pass

    @abstractmethod
    def get_output_path(self, job_id: str) -> Optional[str]:
        """Retrieves the verified output clip path for a completed job."""
        pass

    @abstractmethod
    def get_provider_info(self) -> Dict[str, Any]:
        """Returns metadata regarding capabilities, supported modes, models, and licensing."""
        pass
