#!/usr/bin/env python3
"""
Renders Kubernetes Secret manifests from Bitwarden item JSON.
Reads Bitwarden JSON from stdin, validates secret fields, and writes
multi-document Kubernetes manifests to stdout for direct piping to kubectl.
"""

import json
import sys
import urllib.parse
from typing import Any, Dict, List


def build_secret(name: str, namespace: str, string_data: Dict[str, str]) -> Dict[str, Any]:
    """Helper to construct an Opaque Kubernetes Secret resource."""
    return {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": name,
            "namespace": namespace,
        },
        "type": "Opaque",
        "stringData": {str(k): str(v) for k, v in string_data.items()},
    }


def render_robusta(fields: Dict[str, str]) -> List[Dict[str, Any]]:
    """Generates robusta-secret-values if SMTP fields are present."""
    required = ["SMTP_USER", "EMAIL_PASS", "SMTP_SERVER", "EMAIL_FROM", "EMAIL_TO"]
    present = [k for k in required if fields.get(k)]
    if not present:
        return []

    missing = [k for k in required if not fields.get(k)]
    if missing:
        sys.stderr.write(f"Error: Incomplete Robusta configuration. Missing: {', '.join(missing)}\n")
        sys.exit(1)

    if fields["EMAIL_PASS"] == "your-email-password-or-app-key":
        sys.stderr.write("Error: EMAIL_PASS contains placeholder text. Please update your Bitwarden vault.\n")
        sys.exit(1)

    encoded_user = urllib.parse.quote(fields["SMTP_USER"], safe="")
    encoded_pass = urllib.parse.quote(fields["EMAIL_PASS"], safe="")
    query = urllib.parse.urlencode({
        "from": fields["EMAIL_FROM"],
        "to": fields["EMAIL_TO"],
    })
    mailto = f"mailtos://{encoded_user}:{encoded_pass}@{fields['SMTP_SERVER']}?{query}"

    values_yaml = (
        "sinksConfig:\n"
        "  - mail_sink:\n"
        "      name: main_mail_sink\n"
        f"      mailto: {json.dumps(mailto)}\n"
    )

    return [build_secret("robusta-secret-values", "monitoring", {"values.yaml": values_yaml})]


def render_hermes(fields: Dict[str, str]) -> List[Dict[str, Any]]:
    """Generates hermes-agent-secrets if Hermes fields are present."""
    tg_token = fields.get("HERMES_TELEGRAM_BOT_TOKEN")
    # Only trigger Hermes secret generation if the primary Hermes token is present
    if not tg_token:
        return []

    tg_users = fields.get("HERMES_TELEGRAM_ALLOWED_USERS")
    openai_key = fields.get("HERMES_OPENAI_API_KEY")
    tavily_key = fields.get("HERMES_TAVILY_API_KEY")
    base_url = fields.get("HERMES_OPENAI_BASE_URL")

    missing = []
    if not tg_users:
        missing.append("HERMES_TELEGRAM_ALLOWED_USERS")
    if not openai_key:
        missing.append("HERMES_OPENAI_API_KEY")

    if missing:
        sys.stderr.write(f"Error: Incomplete Hermes configuration. Missing: {', '.join(missing)}\n")
        sys.exit(1)

    data: Dict[str, str] = {
        "TELEGRAM_BOT_TOKEN": tg_token,
        "TELEGRAM_ALLOWED_USERS": tg_users,
        "OPENAI_API_KEY": openai_key,
    }
    if base_url:
        data["OPENAI_BASE_URL"] = base_url
    if tavily_key:
        data["TAVILY_API_KEY"] = tavily_key

    gh_fields = [k for k in ["HERMES_GITHUB_APP_ID", "HERMES_GITHUB_INSTALLATION_ID", "HERMES_GITHUB_APP_PRIVATE_KEY"] if fields.get(k)]
    if gh_fields:
        if len(gh_fields) < 3:
            missing_gh = [k for k in ["HERMES_GITHUB_APP_ID", "HERMES_GITHUB_INSTALLATION_ID", "HERMES_GITHUB_APP_PRIVATE_KEY"] if not fields.get(k)]
            sys.stderr.write(f"Error: Incomplete Hermes GitHub App configuration. Missing: {', '.join(missing_gh)}\n")
            sys.exit(1)
        data["GITHUB_APP_ID"] = str(fields["HERMES_GITHUB_APP_ID"]).strip()
        data["GITHUB_INSTALLATION_ID"] = str(fields["HERMES_GITHUB_INSTALLATION_ID"]).strip()
        raw_key = str(fields["HERMES_GITHUB_APP_PRIVATE_KEY"]).strip()
        raw_key = raw_key.replace("\r\n", "\n").replace("\r", "\n").replace("\\n", "\n").strip()
        data["GITHUB_APP_PRIVATE_KEY"] = raw_key + "\n"
    else:
        # Provide empty placeholder to prevent Kubelet volume mount failure when optional keys are not configured
        data["GITHUB_APP_PRIVATE_KEY"] = ""

    return [build_secret("hermes-agent-secrets", "hermes-agent", data)]


def main() -> None:
    try:
        raw_data = json.load(sys.stdin)
    except Exception as e:
        sys.stderr.write(f"Error reading Bitwarden JSON from stdin: {e}\n")
        sys.exit(1)

    fields = {
        str(f.get("name")): str(f.get("value"))
        for f in raw_data.get("fields", [])
        if f.get("name") and f.get("value") is not None
    }

    manifests: List[Dict[str, Any]] = []
    manifests.extend(render_robusta(fields))
    manifests.extend(render_hermes(fields))

    if not manifests:
        sys.stderr.write("Warning: No matching secrets generated from Bitwarden item fields.\n")
        return

    for i, manifest in enumerate(manifests):
        if i > 0:
            sys.stdout.write("---\n")
        json.dump(manifest, sys.stdout, indent=2)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
