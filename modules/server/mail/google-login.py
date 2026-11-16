import json
import subprocess
import sys
import urllib.parse

ORTIE = "@ortie@"


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: google-login <account>")
    account = sys.argv[1]
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
    print(f"Signed in as {account}.")


if __name__ == "__main__":
    main()
