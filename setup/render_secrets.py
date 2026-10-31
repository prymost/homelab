#!/usr/bin/env python3
"""
Renders Kubernetes Secret manifests from Bitwarden item JSON.
Reads Bitwarden JSON from stdin, validates secret fields, and writes
multi-document Kubernetes manifests to stdout for direct piping to kubectl.
"""

import json
import sys
import urllib.parse
from typing import Any, Dict, List, NoReturn


def fail(message: str) -> NoReturn:
    """Print an error message to stderr and terminate with non-zero exit code."""
    sys.stderr.write(f"Error: {message}\n")
    sys.exit(1)


def build_secret(name: str, namespace: str, string_data: Dict[str, str]) -> Dict[str, Any]:
    """Construct an Opaque Kubernetes Secret resource."""
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


def check_atomic_group(fields: Dict[str, str], group_name: str, keys: List[str]) -> bool:
    """Check if an atomic group of keys is fully present, fully absent, or invalid (partial)."""
    present = [k for k in keys if fields.get(k)]
    if not present:
        return False
    missing = [k for k in keys if not fields.get(k)]
    if missing:
        fail(f"Incomplete {group_name} configuration. Missing: {', '.join(missing)}")
    return True


def parse_json_object(field_name: str, raw: str) -> Dict[str, Any]:
    """Parse string as a JSON dictionary or exit with a clear error."""
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    fail(f"Field {field_name} must be a valid JSON object")


def validate_client_secret(raw: str) -> str:
    """Ensure Google Client Secret contains a valid client_id."""
    data = parse_json_object("HERMES_GOOGLE_CLIENT_SECRET", raw)
    config = data.get("installed") or data.get("web") or data
    if not isinstance(config, dict) or "client_id" not in config:
        fail("Missing 'client_id' in Google Client Secret JSON")
    return str(raw).strip()


def validate_google_token(raw: str) -> str:
    """Ensure Google User Token contains a non-empty refresh_token."""
    data = parse_json_object("HERMES_GOOGLE_TOKEN", raw)
    ref_tok = data.get("refresh_token")
    if not ref_tok or not isinstance(ref_tok, str) or not ref_tok.strip():
        fail("Field 'refresh_token' in Google Token JSON must be a non-empty string")
    return str(raw).strip()


def normalize_pem_key(raw_key: str) -> str:
    """Normalize multi-line RSA PEM key line endings."""
    clean = str(raw_key).strip()
    clean = clean.replace("\r\n", "\n").replace("\r", "\n").replace("\\n", "\n").strip()
    return clean + "\n"


def render_robusta(fields: Dict[str, str]) -> List[Dict[str, Any]]:
    """Generates robusta-secret-values if SMTP fields are present."""
    required = ["SMTP_USER", "EMAIL_PASS", "SMTP_SERVER", "EMAIL_FROM", "EMAIL_TO"]
    if not check_atomic_group(fields, "Robusta", required):
        return []

    if fields["EMAIL_PASS"] == "your-email-password-or-app-key":
        fail("EMAIL_PASS contains placeholder text. Please update your Bitwarden vault.")

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
    core_keys = ["HERMES_TELEGRAM_BOT_TOKEN", "HERMES_TELEGRAM_ALLOWED_USERS", "HERMES_OPENAI_API_KEY"]
    if not fields.get("HERMES_TELEGRAM_BOT_TOKEN"):
        return []

    check_atomic_group(fields, "Hermes core", core_keys)

    data: Dict[str, str] = {
        "TELEGRAM_BOT_TOKEN": fields["HERMES_TELEGRAM_BOT_TOKEN"],
        "TELEGRAM_ALLOWED_USERS": fields["HERMES_TELEGRAM_ALLOWED_USERS"],
        "OPENAI_API_KEY": fields["HERMES_OPENAI_API_KEY"],
    }
    if fields.get("HERMES_OPENAI_BASE_URL"):
        data["OPENAI_BASE_URL"] = fields["HERMES_OPENAI_BASE_URL"]
    if fields.get("HERMES_TAVILY_API_KEY"):
        data["TAVILY_API_KEY"] = fields["HERMES_TAVILY_API_KEY"]

    # Optional atomic group: LINQ Connect school lunch parameters
    linq_keys = ["HERMES_LINQ_BUILDING_ID", "HERMES_LINQ_DISTRICT_ID"]
    if check_atomic_group(fields, "Hermes LINQ", linq_keys):
        data["LINQ_BUILDING_ID"] = str(fields["HERMES_LINQ_BUILDING_ID"]).strip()
        data["LINQ_DISTRICT_ID"] = str(fields["HERMES_LINQ_DISTRICT_ID"]).strip()

    # Optional atomic group: GitHub App authentication
    gh_keys = ["HERMES_GITHUB_APP_ID", "HERMES_GITHUB_INSTALLATION_ID", "HERMES_GITHUB_APP_PRIVATE_KEY"]
    if check_atomic_group(fields, "Hermes GitHub App", gh_keys):
        data["GITHUB_APP_ID"] = str(fields["HERMES_GITHUB_APP_ID"]).strip()
        data["GITHUB_INSTALLATION_ID"] = str(fields["HERMES_GITHUB_INSTALLATION_ID"]).strip()
        data["GITHUB_APP_PRIVATE_KEY"] = normalize_pem_key(fields["HERMES_GITHUB_APP_PRIVATE_KEY"])
    else:
        # Provide empty placeholder to prevent Kubelet volume mount failure when optional keys are not configured
        data["GITHUB_APP_PRIVATE_KEY"] = ""

    return [build_secret("hermes-agent-secrets", "hermes-agent", data)]


def render_hermes_gcal(fields: Dict[str, str]) -> List[Dict[str, Any]]:
    """Generates hermes-agent-gcal-secrets if Google Calendar fields are present."""
    gcal_keys = ["HERMES_GOOGLE_CLIENT_SECRET", "HERMES_GOOGLE_TOKEN"]
    if not check_atomic_group(fields, "Hermes Google Calendar", gcal_keys):
        return []

    return [build_secret("hermes-agent-gcal-secrets", "hermes-agent", {
        "google-client-secret.json": validate_client_secret(fields["HERMES_GOOGLE_CLIENT_SECRET"]),
        "google-token.json": validate_google_token(fields["HERMES_GOOGLE_TOKEN"]),
    })]


def main() -> None:
    try:
        raw_data = json.load(sys.stdin)
    except Exception as e:
        fail(f"reading Bitwarden JSON from stdin: {e}")

    fields = {
        str(f.get("name")): str(f.get("value"))
        for f in raw_data.get("fields", [])
        if f.get("name") and f.get("value") is not None
    }

    manifests: List[Dict[str, Any]] = []
    manifests.extend(render_robusta(fields))
    manifests.extend(render_hermes(fields))
    manifests.extend(render_hermes_gcal(fields))

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
