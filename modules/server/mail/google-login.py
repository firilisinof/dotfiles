import json
import os
import pathlib
import subprocess
import sys
import urllib.parse

ORTIE = "@ortie@"
STATE = "@state@"


def share_with_calendar(account):
    """vdirsyncer signs in by itself otherwise, so hand it the same refresh token."""
    token = json.loads(pathlib.Path(STATE, "ortie", account).read_text())
    target = pathlib.Path(STATE, "vdirsyncer", f"google-{account}.json")
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w") as file:
        # an expiry in the past makes vdirsyncer refresh on first use
        json.dump(
            {
                "access_token": token["access_token"],
                "refresh_token": token["refresh_token"],
                "token_type": "Bearer",
                "expires_at": 1,
            },
            file,
        )
    temporary.replace(target)


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[2:] not in ([], ["--reuse"]):
        raise SystemExit("usage: google-login <account> [--reuse]")
    account = sys.argv[1]
    if sys.argv[2:]:
        share_with_calendar(account)
        print(f"Calendar access for {account} now uses the existing sign-in.")
        return
    started = subprocess.run(
        [ORTIE, "auth", "get", "-a", account, "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    flow = json.loads(started.stdout)
    query = urllib.parse.parse_qs(
        urllib.parse.urlsplit(flow["authorization_uri"]).query
    )
    print("Open this address in a browser and sign in:\n")
    print(flow["authorization_uri"])
    print(
        "\nThe browser ends on a page that fails to load, at an address starting with"
        f"\n{query['redirect_uri'][0]}\nPaste that whole address here.\n"
    )
    redirected = input("> ").strip()
    command = [ORTIE, "auth", "resume", "-a", account]
    command += ["--redirect-uri", query["redirect_uri"][0]]
    if flow.get("state"):
        command += ["--state", flow["state"]]
    if flow.get("pkce_code_verifier"):
        command += ["--pkce", flow["pkce_code_verifier"]]
    subprocess.run(command + [redirected], check=True, stdout=subprocess.DEVNULL)
    share_with_calendar(account)
    print(f"Signed in as {account}.")


if __name__ == "__main__":
    main()
