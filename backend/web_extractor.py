"""
Website metadata and brand asset extractor for AppGrowth Studio + ViMax.
Extracts title, description, brand name, logo, open-graph imagery,
product features, calls to action, and visual identity from public URLs.
"""

from __future__ import annotations

import os
import re
import urllib.parse
from typing import Any, Dict, List, Optional
import requests
try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None


class WebExtractor:
    def __init__(self, cache_dir: str = "backend/cache"):
        self.cache_dir = os.path.abspath(cache_dir)
        os.makedirs(self.cache_dir, exist_ok=True)
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        })

    def extract(self, url: str) -> Dict[str, Any]:
        """Extracts brand and product metadata from a public website URL."""
        normalized_url = url.strip()
        if not normalized_url.startswith(("http://", "https://")):
            normalized_url = "https://" + normalized_url

        parsed_url = urllib.parse.urlparse(normalized_url)
        domain = parsed_url.netloc or "example.com"
        clean_domain = domain.replace("www.", "")

        result: Dict[str, Any] = {
            "url": normalized_url,
            "domain": clean_domain,
            "brand_name": self._infer_brand_name(clean_domain),
            "title": "",
            "description": "",
            "features": [],
            "call_to_action": "Get Started Today",
            "logo_url": "",
            "hero_image_url": "",
            "brand_color": "#2563EB",
            "local_images": [],
            "is_accessible": False,
            "error": None,
        }

        try:
            response = self.session.get(normalized_url, timeout=12, allow_redirects=True)
            if response.status_code >= 400:
                result["error"] = f"HTTP {response.status_code}: Unable to load page"
                result["title"] = f"{result['brand_name']} - Smart Solution"
                result["description"] = f"Discover {result['brand_name']}, the modern tool for {clean_domain}."
                return result

            result["is_accessible"] = True
            html = response.text

            # 1. Title
            title_match = re.search(r"<title[^>]*>(.*?)</title>", html, re.IGNORECASE | re.DOTALL)
            if title_match:
                raw_title = self._clean_text(title_match.group(1))
                result["title"] = raw_title
                # Refine brand name if title has "Brand | Tagline" or "Brand - Tagline"
                parts = re.split(r"[-|:–•]", raw_title)
                if parts and len(parts[0].strip()) > 1:
                    first_part = parts[0].strip()
                    if len(first_part) < 30:
                        result["brand_name"] = first_part

            # 2. Meta description
            desc_match = re.search(r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']', html, re.IGNORECASE)
            if not desc_match:
                desc_match = re.search(r'<meta[^>]+content=["\'](.*?)["\'][^>]+name=["\']description["\']', html, re.IGNORECASE)
            if desc_match:
                result["description"] = self._clean_text(desc_match.group(1))

            # 3. OpenGraph / Twitter Cards
            og_title = self._extract_meta_prop(html, "og:title") or self._extract_meta_name(html, "twitter:title")
            if og_title and not result["title"]:
                result["title"] = self._clean_text(og_title)

            og_desc = self._extract_meta_prop(html, "og:description") or self._extract_meta_name(html, "twitter:description")
            if og_desc and not result["description"]:
                result["description"] = self._clean_text(og_desc)

            og_site_name = self._extract_meta_prop(html, "og:site_name")
            if og_site_name:
                result["brand_name"] = self._clean_text(og_site_name)

            og_image = self._extract_meta_prop(html, "og:image") or self._extract_meta_name(html, "twitter:image")
            if og_image:
                result["hero_image_url"] = urllib.parse.urljoin(normalized_url, og_image.strip())

            # 4. Brand Color
            theme_color = self._extract_meta_name(html, "theme-color")
            if theme_color and re.match(r"^#(?:[0-9a-fA-F]{3}){1,2}$", theme_color.strip()):
                result["brand_color"] = theme_color.strip()

            # 5. Logo / Favicon
            favicon = self._extract_favicon(html, normalized_url)
            if favicon:
                result["logo_url"] = favicon

            # 6. Extract Key Features from Headings & List Items
            features = self._extract_features(html)
            if features:
                result["features"] = features
            else:
                result["features"] = [
                    f"Seamless {result['brand_name']} experience",
                    "Intuitive modern workflow",
                    "High performance & automated productivity",
                    "Built for modern teams and users",
                ]

            # 7. Extract Call To Action
            cta = self._extract_cta(html)
            if cta:
                result["call_to_action"] = cta

            # 8. Download hero/logo images locally for offline rendering
            if result["hero_image_url"]:
                local_path = self._cache_image(result["hero_image_url"], f"hero_{clean_domain}")
                if local_path:
                    result["local_images"].append(local_path)

            if result["logo_url"]:
                local_logo = self._cache_image(result["logo_url"], f"logo_{clean_domain}")
                if local_logo:
                    result["local_logo"] = local_logo

        except Exception as e:
            result["error"] = f"Extraction notice: {str(e)}"
            if not result["title"]:
                result["title"] = f"{result['brand_name']} - Official Product"
            if not result["description"]:
                result["description"] = f"Streamline your workflow with {result['brand_name']}."
            if not result["features"]:
                result["features"] = [
                    f"Fast, reliable {result['brand_name']} features",
                    "Simple setup with immediate results",
                    "Designed for efficiency",
                ]

        return result

    def _infer_brand_name(self, domain: str) -> str:
        parts = domain.split(".")
        name = parts[0] if parts else "Brand"
        return name.replace("-", " ").title()

    def _clean_text(self, text: str) -> str:
        text = re.sub(r"&[a-zA-Z0-9#]+;", " ", text)
        text = re.sub(r"\s+", " ", text)
        return text.strip()

    def _extract_meta_prop(self, html: str, prop: str) -> Optional[str]:
        m = re.search(rf'<meta[^>]+property=["\']{prop}["\'][^>]+content=["\'](.*?)["\']', html, re.IGNORECASE)
        if not m:
            m = re.search(rf'<meta[^>]+content=["\'](.*?)["\'][^>]+property=["\']{prop}["\']', html, re.IGNORECASE)
        return m.group(1) if m else None

    def _extract_meta_name(self, html: str, name: str) -> Optional[str]:
        m = re.search(rf'<meta[^>]+name=["\']{name}["\'][^>]+content=["\'](.*?)["\']', html, re.IGNORECASE)
        if not m:
            m = re.search(rf'<meta[^>]+content=["\'](.*?)["\'][^>]+name=["\']{name}["\']', html, re.IGNORECASE)
        return m.group(1) if m else None

    def _extract_favicon(self, html: str, base_url: str) -> Optional[str]:
        icons = re.findall(r'<link[^>]+rel=["\'](?:shortcut icon|icon|apple-touch-icon)["\'][^>]+href=["\'](.*?)["\']', html, re.IGNORECASE)
        if icons:
            return urllib.parse.urljoin(base_url, icons[0].strip())
        return urllib.parse.urljoin(base_url, "/favicon.ico")

    def _extract_features(self, html: str) -> List[str]:
        features: List[str] = []
        # Find h2, h3 tags
        headings = re.findall(r'<h[23][^>]*>(.*?)</h[23]>', html, re.IGNORECASE | re.DOTALL)
        for h in headings:
            cleaned = self._clean_text(re.sub(r"<[^>]+>", "", h))
            if 10 <= len(cleaned) <= 75 and not any(skip in cleaned.lower() for skip in ["cookie", "privacy", "terms", "subscribe", "newsletter"]):
                features.append(cleaned)
            if len(features) >= 5:
                break
        return features

    def _extract_cta(self, html: str) -> Optional[str]:
        matches = re.findall(r'<(?:a|button)[^>]+class=["\'][^"\']*(?:btn|cta|button)[^"\']*["\'][^>]*>(.*?)</(?:a|button)>', html, re.IGNORECASE | re.DOTALL)
        for m in matches:
            cleaned = self._clean_text(re.sub(r"<[^>]+>", "", m))
            if 3 <= len(cleaned) <= 30 and any(w in cleaned.lower() for w in ["start", "get", "try", "join", "sign", "download", "book", "demo", "explore"]):
                return cleaned
        return None

    def _cache_image(self, img_url: str, filename_prefix: str) -> Optional[str]:
        try:
            res = self.session.get(img_url, timeout=8, stream=True)
            if res.status_code == 200:
                ext = ".png"
                if "jpeg" in res.headers.get("Content-Type", "").lower() or ".jpg" in img_url.lower():
                    ext = ".jpg"
                elif "webp" in res.headers.get("Content-Type", "").lower():
                    ext = ".webp"
                safe_name = f"{filename_prefix}_{abs(hash(img_url)) % 100000}{ext}"
                target = os.path.join(self.cache_dir, safe_name)
                with open(target, "wb") as f:
                    for chunk in res.iter_content(chunk_size=8192):
                        f.write(chunk)
                if os.path.exists(target) and os.path.getsize(target) > 500:
                    return target
        except Exception:
            pass
        return None
