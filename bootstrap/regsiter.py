#!/usr/bin/env python3
import sys
import platform
import socket
import uuid
import requests

def get_jwt_access_token(oidc_token_url, client_id, client_secret):
    token_resp = requests.post(
        oidc_token_url,
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    token_resp.raise_for_status()
    access_token = token_resp.json()["access_token"]
    return access_token


def main():
    if len(sys.argv) < 6:
        print("Usage: register.py <api_url> <public_key> <oidc_token_url> <client_id> <client_secret>", file=sys.stderr)
        sys.exit(1)

    api_url = sys.argv[1]
    public_key = sys.argv[2]
    oidc_token_url = sys.argv[3]
    client_id = sys.argv[4]
    client_secret = sys.argv[5]

    # Step 1: Get JWT access token via client_credentials grant
    access_token = get_jwt_access_token(oidc_token_url, client_id, client_secret)

    # Step 2: Prepare metadata
    metadata = {
        "hostname": socket.gethostname(),
        "os": platform.system(),
        "uuid": str(uuid.uuid4()),
        "public_key": public_key,
    }

    # Step 3: Register with API
    response = requests.post(
        api_url,
        json=metadata,
        headers={"Authorization": f"Bearer {access_token}"}
    )
    response.raise_for_status()
    data = response.json()

    # Assume API response contains {"repo_url": "git@github.com:org/repo.git"}
    print(data["repo_url"])

if __name__ == "__main__":
    main()
