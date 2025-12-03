#!/bin/sh
set -e

DATA_DIR="/data"
CONF_FILE="$DATA_DIR/ca.conf"
CA_KEY="$DATA_DIR/ca.key"
CA_CERT="$DATA_DIR/ca.crt"
CRL_FILE="$DATA_DIR/crl.pem"
INDEX_FILE="$DATA_DIR/index.txt"
SERIAL_FILE="$DATA_DIR/serial"

create_config() {
    cat > "$CONF_FILE" <<EOF
[ ca ]
default_ca = my_ca

[ my_ca ]
dir             = $DATA_DIR
database        = $INDEX_FILE
new_certs_dir   = $DATA_DIR
certificate     = $CA_CERT
private_key     = $CA_KEY
serial          = $SERIAL_FILE
crlnumber       = $DATA_DIR/crlnumber
default_md      = sha384
default_days    = 3650
default_crl_days= 30
policy          = policy_loose
copy_extensions = copy

[ policy_loose ]
commonName      = supplied
serialNumber    = optional
EOF
}

cmd_init() {
    mkdir -p "$DATA_DIR"
    if [ -f "$CA_KEY" ]; then
        echo "CA already exists." >&2
        exit 1
    fi

    echo "Initializing CA (ECDSA P-384)..."
    touch "$INDEX_FILE"
    echo "1000" > "$SERIAL_FILE"
    echo "1000" > "$DATA_DIR/crlnumber"
    create_config

    # Create CA Private Key (ECC)
    openssl ecparam -name secp384r1 -genkey -noout -out "$CA_KEY"

    # Sign Root Cert (Self-Signed, SHA-384)
    openssl req -new -x509 -days 3650 -key "$CA_KEY" -out "$CA_CERT" \
        -subj "/CN=Private CA" -sha384

    # Initial CRL
    openssl ca -config "$CONF_FILE" -gencrl -out "$CRL_FILE"
    
    echo "CA Initialized"
}

cmd_new() {
    NAME="$1"
    UUID="$2"
    PASSWORD="${3:-changeit}" 

    if [ -z "$NAME" ] || [ -z "$UUID" ]; then
        echo "Usage: new-client <name> <uuid> [password]" >&2
        exit 1
    fi

    SAFE_NAME=$(echo "$NAME" | tr -cd 'a-zA-Z0-9_-')
    KEY_FILE="$DATA_DIR/$SAFE_NAME.key"
    CSR_FILE="$DATA_DIR/$SAFE_NAME.csr"
    CRT_FILE="$DATA_DIR/$SAFE_NAME.crt"
    P12_FILE="$DATA_DIR/$SAFE_NAME.p12"

    echo "Creating Client Cert for $NAME..."

    # Client Key (ECC P-384)
    openssl ecparam -name secp384r1 -genkey -noout -out "$KEY_FILE"

    # CSR (SHA-384)
    SUBJECT="/CN=$NAME/serialNumber=$UUID"
    openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "$SUBJECT" -sha384

    # Sign (2 Years)
    openssl ca -config "$CONF_FILE" -batch -days 825 -in "$CSR_FILE" -out "$CRT_FILE"

    # Export P12 (AES-256 Encryption with PASSWORD)
    openssl pkcs12 -export -out "$P12_FILE" \
        -inkey "$KEY_FILE" -in "$CRT_FILE" -certfile "$CA_CERT" \
        -keypbe AES-256-CBC -certpbe AES-256-CBC \
        -passout "pass:$PASSWORD"

    rm "$CSR_FILE"
    
    echo "Created $P12_FILE"
    echo "Import Password: $PASSWORD"
}

cmd_revoke() {
    NAME="$1"
    SAFE_NAME=$(echo "$NAME" | tr -cd 'a-zA-Z0-9_-')
    CRT_FILE="$DATA_DIR/$SAFE_NAME.crt"

    if [ ! -f "$CRT_FILE" ]; then
        echo "Cert not found." >&2
        exit 1
    fi

    echo "Revoking $NAME..."
    openssl ca -config "$CONF_FILE" -revoke "$CRT_FILE"
    openssl ca -config "$CONF_FILE" -gencrl -out "$CRL_FILE"
    echo "Revoked."
}

case "$1" in
    "init") cmd_init ;;
    "new-client") cmd_new "$2" "$3" "$4" ;;
    "revoke") cmd_revoke "$2" ;;
    *) echo "Usage: $0 {init|new-client <name> <uuid> [password]|revoke <name>}"; exit 1 ;;
esac

