#!/usr/bin/env python3
"""Check platform app versions against latest available."""

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

try:
    import yaml
except ImportError:
    print("Error: PyYAML is not installed.")
    print("Install with: pip3 install pyyaml")
    print("Or: pip install pyyaml")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("Error: requests is not installed.")
    print("Install with: pip3 install requests")
    print("Or: pip install requests")
    sys.exit(1)

# Colors for output
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color

BASE_DIR = Path("gitops/clusters/starbase")
PLATFORM_DIR = BASE_DIR / "applications" / "platform"


def get_latest_helm_version(repo_url: str, chart_name: str) -> str:
    """Get latest version of a Helm chart."""
    try:
        # Add repo temporarily
        repo_name = "temp-check-repo"
        subprocess.run(
            ["helm", "repo", "add", repo_name, repo_url],
            capture_output=True,
            check=False
        )
        subprocess.run(
            ["helm", "repo", "update", repo_name],
            capture_output=True,
            check=False
        )

        # Get chart version
        result = subprocess.run(
            ["helm", "show", "chart", f"{repo_name}/{chart_name}"],
            capture_output=True,
            text=True,
            check=False
        )

        # Clean up
        subprocess.run(
            ["helm", "repo", "remove", repo_name],
            capture_output=True,
            check=False
        )

        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if line.startswith('version:'):
                    return line.split(':', 1)[1].strip()
    except Exception:
        pass

    return "unknown"


def get_latest_docker_tag(image: str) -> str:
    """Get latest Docker image tag from Docker Hub or Quay.io."""
    try:
        if 'quay.io' in image:
            # Quay.io API
            repo = image.replace('quay.io/', '')
            url = f"https://quay.io/api/v1/repository/{repo}/tag"
            response = requests.get(url, params={'limit': 100, 'onlyActiveTags': 'true'}, timeout=10)
            if response.status_code == 200:
                data = response.json()
                tags = [tag['name'] for tag in data.get('tags', [])]
                # Filter version tags (v0.14.5, v0.14.6, etc.)
                version_tags = [t for t in tags if re.match(r'^v?\d+\.\d+', t)]
                if version_tags:
                    # Sort by version number
                    def version_key(tag):
                        # Remove 'v' prefix and split by dots
                        version = tag.lstrip('v')
                        return tuple(int(x) for x in version.split('.') if x.isdigit())
                    version_tags.sort(key=version_key)
                    return version_tags[-1]
        else:
            # Docker Hub API
            repo = image.split('/')[-1] if '/' in image else image
            namespace = image.split('/')[0] if '/' in image else 'library'
            url = f"https://hub.docker.com/v2/repositories/{namespace}/{repo}/tags"

            if 'cloudflare/cloudflared' in image:
                # Cloudflared uses date-based tags
                response = requests.get(url, params={'page_size': 100}, timeout=10)
                if response.status_code == 200:
                    tags = [tag['name'] for tag in response.json().get('results', [])]
                    date_tags = [t for t in tags if re.match(r'^\d{4}\.\d{2}\.\d+$', t)]
                    if date_tags:
                        date_tags.sort()
                        return date_tags[-1]
            else:
                # Standard version tags
                response = requests.get(url, params={'page_size': 100}, timeout=10)
                if response.status_code == 200:
                    tags = [tag['name'] for tag in response.json().get('results', [])]
                    version_tags = [t for t in tags if re.match(r'^v?\d+\.\d+', t)]
                    if version_tags:
                        version_tags.sort(key=lambda x: [int(i) for i in re.findall(r'\d+', x)])
                        return version_tags[-1]
    except Exception:
        pass

    return "unknown"


def check_argocd_chart_version() -> str:
    """Check ArgoCD Helm chart version from cluster."""
    try:
        result = subprocess.run(
            ["helm", "list", "-n", "argocd", "-o", "json"],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0 and result.stdout:
            import json
            releases = json.loads(result.stdout)
            for release in releases:
                if release.get('name') == 'argocd':
                    chart = release.get('chart', '')
                    # Extract version from chart string like "argo-cd-9.2.4"
                    match = re.search(r'argo-cd-(\d+\.\d+\.\d+)', chart)
                    if match:
                        return match.group(1)
    except Exception:
        pass

    return "unknown"


def extract_image_from_yaml(file_path: Path) -> Optional[Tuple[str, str]]:
    """Extract image and tag from YAML files in a directory."""
    image_pattern = re.compile(r'image:\s+([^:\s]+):([^\s]+)')

    for yaml_file in file_path.rglob("*.yaml"):
        try:
            with open(yaml_file, 'r') as f:
                content = f.read()
                match = image_pattern.search(content)
                if match:
                    return match.group(1), match.group(2)
        except Exception:
            continue

    return None


def process_application(file_path: Path) -> Optional[dict]:
    """Process an ArgoCD application file and return version info."""
    try:
        with open(file_path, 'r') as f:
            app = yaml.safe_load(f)

        app_name = file_path.stem.replace('-application', '')
        source = app.get('spec', {}).get('source', {})

        # Check if it's a Helm chart
        if 'chart' in source:
            repo_url = source.get('repoURL', '')
            chart = source.get('chart', '')
            current = source.get('targetRevision', '')

            if repo_url and chart and current:
                latest = get_latest_helm_version(repo_url, chart)
                return {
                    'name': app_name,
                    'current': current,
                    'latest': latest,
                    'type': 'helm'
                }

        # Check if it's git-based (look for Docker images)
        elif 'path' in source:
            path = source.get('path', '')
            if path:
                git_path = Path("gitops") / path.replace('gitops/', '')
                if git_path.exists():
                    image_info = extract_image_from_yaml(git_path)
                    if image_info:
                        image, current_tag = image_info
                        latest = get_latest_docker_tag(image)
                        return {
                            'name': app_name,
                            'current': current_tag,
                            'latest': latest,
                            'type': 'docker'
                        }
    except Exception as e:
        # Silently skip files that can't be parsed
        pass

    return None


def main():
    """Main function."""
    print("Checking platform app versions...")
    print()

    # Header
    print(f"{'Application':<25} {'Current':<15} {'Latest'}")
    print("-" * 70)

    # Check ArgoCD (Helm chart version)
    argocd_current = check_argocd_chart_version()
    argocd_latest = get_latest_helm_version("https://argoproj.github.io/argo-helm", "argo-cd")

    if argocd_current == argocd_latest or argocd_latest == "unknown":
        print(f"{GREEN}argocd{'':<20} {argocd_current:<15} {argocd_latest}{NC}")
    else:
        print(f"{YELLOW}argocd{'':<20} {argocd_current:<15} {argocd_latest}{NC}")

    # Process platform applications
    results = []
    if PLATFORM_DIR.exists():
        for app_file in sorted(PLATFORM_DIR.glob("*-application.yaml")):
            result = process_application(app_file)
            if result:
                results.append(result)

    # Sort and display results
    for result in sorted(results, key=lambda x: x['name']):
        name = result['name']
        current = result['current']
        latest = result['latest']

        if latest == "unknown":
            print(f"{name:<25} {current:<15} {latest}")
        elif current == latest:
            print(f"{GREEN}{name:<25} {current:<15} {latest} (latest){NC}")
        else:
            print(f"{YELLOW}{name:<25} {current:<15} {latest}{NC}")

    print()
    print(f"Legend: {GREEN}Green{NC} = up to date, {YELLOW}Yellow{NC} = update available")


if __name__ == "__main__":
    main()
