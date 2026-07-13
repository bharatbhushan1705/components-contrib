#!/usr/bin/env bash
# Regenerates the self-signed certificates used by the mTLS certification scenario.
set -euo pipefail
cd "$(dirname "$0")"

openssl req -x509 -newkey rsa:2048 -keyout ca.key.pem -out ca.cert.pem -days 3650 -nodes -subj "/CN=Pulsar Certification Test CA"

openssl req -newkey rsa:2048 -keyout broker.key.pem -out broker.csr -nodes -subj "/CN=localhost"
openssl x509 -req -in broker.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out broker.cert.pem -days 3650 \
  -extfile <(printf "subjectAltName=DNS:localhost,DNS:standalone,IP:127.0.0.1")
openssl pkcs8 -topk8 -nocrypt -in broker.key.pem -out broker.key-pk8.pem

openssl req -newkey rsa:2048 -keyout client.key.pem -out client.csr -nodes -subj "/CN=admin"
openssl x509 -req -in client.csr -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -out client.cert.pem -days 3650
openssl pkcs8 -topk8 -nocrypt -in client.key.pem -out client.key-pk8.pem

rm -f broker.csr client.csr *.srl
chmod 644 *.pem
