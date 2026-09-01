#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"

ROOT_CA="$CERT_DIR/rootCA.crt"
ROOT_KEY="$CERT_DIR/rootCA.key"

SERVER_KEY="$CERT_DIR/vaultwarden.key"
SERVER_CRT="$CERT_DIR/vaultwarden.crt"
SERVER_CHAIN="$CERT_DIR/vaultwarden-chain-completa.crt"
SERVER_CSR="$CERT_DIR/vaultwarden.csr"
SERVER_EXT="$CERT_DIR/vaultwarden-ext.cnf"

COUNTRY="YOUR_COUNTRY"
COUNTRYCODE="YOUR_COUNTRY_CODE"
CITY="YOUR_CITY"
IP="IP_SERVER"

# Rinnova se mancano 30 giorni o meno
RENEW_SECONDS=$((30 * 24 * 60 * 60))

echo "=============================================="
echo " Vaultwarden - controllo certificato"
echo "=============================================="

# ------------------------------------------------
# Controllo Root CA
# ------------------------------------------------

if [ ! -f "$ROOT_CA" ]; then
    echo "ERRORE: Root CA non trovata:"
    echo "$ROOT_CA"
    exit 1
fi

if [ ! -f "$ROOT_KEY" ]; then
    echo "ERRORE: chiave Root CA non trovata:"
    echo "$ROOT_KEY"
    exit 1
fi

# ------------------------------------------------
# Controllo certificato esistente
# ------------------------------------------------

if [ -f "$SERVER_CRT" ]; then

    echo
    echo "Certificato attuale:"
    openssl x509 \
        -in "$SERVER_CRT" \
        -noout \
        -subject \
        -issuer \
        -dates \
        -ext subjectAltName

    if openssl x509 \
        -checkend "$RENEW_SECONDS" \
        -noout \
        -in "$SERVER_CRT" >/dev/null 2>&1
    then
        echo
        echo "Il certificato è valido per più di 30 giorni."
        echo "Nessun rinnovo necessario."
        exit 0
    fi

else
    echo
    echo "Certificato Vaultwarden non trovato."
    echo "Verrà generato."
fi

# ------------------------------------------------
# Chiave privata
# ------------------------------------------------

if [ ! -f "$SERVER_KEY" ]; then

    echo
    echo "Genero la chiave privata Vaultwarden..."

    openssl genrsa \
        -out "$SERVER_KEY" \
        4096

    chmod 600 "$SERVER_KEY"

else

    echo
    echo "Mantengo la chiave privata Vaultwarden esistente."

fi

# ------------------------------------------------
# Configurazione certificato
# ------------------------------------------------

cat > "$SERVER_EXT" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=IP:$IP
EOF

# ------------------------------------------------
# CSR
# ------------------------------------------------

echo
echo "Genero CSR..."

openssl req \
    -new \
    -sha256 \
    -key "$SERVER_KEY" \
    -out "$SERVER_CSR" \
    -subj "/C=$COUNTRYCODE/ST=$COUNTRY/L=$CITY/O=HomeLab/CN=$IP"

# ------------------------------------------------
# Certificato firmato dalla Root CA
# ------------------------------------------------

echo
echo "Firmo il certificato con la Root CA..."

openssl x509 \
    -req \
    -sha256 \
    -in "$SERVER_CSR" \
    -CA "$ROOT_CA" \
    -CAkey "$ROOT_KEY" \
    -CAcreateserial \
    -out "$SERVER_CRT" \
    -days 825 \
    -extfile "$SERVER_EXT"

# ------------------------------------------------
# Full chain
# ------------------------------------------------

echo
echo "Creo la full chain..."

cat "$SERVER_CRT" "$ROOT_CA" > "$SERVER_CHAIN"

# ------------------------------------------------
# Verifica
# ------------------------------------------------

echo
echo "=============================================="
echo " Certificato nuovo"
echo "=============================================="

openssl x509 \
    -in "$SERVER_CRT" \
    -noout \
    -subject \
    -issuer \
    -dates \
    -ext subjectAltName

# ------------------------------------------------
# Test Nginx
# ------------------------------------------------

echo
echo "Controllo configurazione Nginx..."

sudo docker exec nginx-ssl nginx -t

# ------------------------------------------------
# Restart
# ------------------------------------------------

echo
echo "Riavvio Nginx..."

sudo docker restart nginx-ssl

echo
echo "=============================================="
echo " RINNOVO VAULTWARDEN COMPLETATO"
echo "=============================================="
