#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$SCRIPT_DIR/certs"
SERVER_KEY="$CERT_DIR/localhost.key"
SERVER_CRT="$CERT_DIR/localhost.crt"

# Rinnova se mancano 30 giorni o meno
RENEW_SECONDS=$((30 * 24 * 60 * 60))

echo "=============================================="
echo " localhost - controllo certificato"
echo "=============================================="

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
        -dates

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
    echo "Certificato localhost non trovato."
    echo "Verrà generato."
fi

# ------------------------------------------------
# Generazione chiave
# ------------------------------------------------
if [ ! -f "$SERVER_KEY" ]; then
    echo
    echo "Genero la chiave localhost..."
    openssl genrsa \
        -out "$SERVER_KEY" \
        2048
    chmod 600 "$SERVER_KEY"
else
    echo
    echo "Mantengo la chiave localhost esistente."
fi

# ------------------------------------------------
# Nuovo certificato self-signed
# ------------------------------------------------
echo
echo "Genero nuovo localhost.crt..."
openssl req \
    -x509 \
    -sha256 \
    -nodes \
    -new \
    -key "$SERVER_KEY" \
    -out "$SERVER_CRT" \
    -days 825 \
    -subj "/CN=localhost"

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
    -dates

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
echo " RINNOVO LOCALHOST COMPLETATO"
echo "=============================================="
