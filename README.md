# client-cert-manager

A lightweight script to manage a private Certificate Authority (CA) and issue client certificates for mTLS.

## Setup

1. Build the image:
```
podman build -t my-ca .
```
2. Create a data directory:
```
mkdir ./my-ca-data
```

## Commands

### Initialize CA
```
podman run --rm -v ./my-ca-data:/data my-ca init
```

### Create Client Certificate
Generates a `.p12` file (AES-256 encrypted) for a user.
* **Usage:** `new-client <name> <UUID> [password]`
* **Default Password:** `changeit`
```
podman run --rm -v ./my-ca-data:/data my-ca new-client \
"MyPhone" \
"000d10000-abcd-dcba-abcd-00000d100000" \
"PASSWORD"
```
