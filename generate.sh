#!/bin/bash -e

# server certificate common name
SERVER_CN=${1:-localhost}

# server certificate alias
SERVER_ALIAS=${2:-localhost.localdomain}

# client certificate common name
CLIENT_CN=${3:-localhost}

# client certificate common name
CLIENT_ALIAS=${4:-localhost}

SUBJECT="/C=US/ST=CA/O=Example.com"
CA_CN="Example CA TESTING"
# https://support.apple.com/en-us/HT210176
DAYS=824
PASSCA=pass:password_ca
PASSSV=pass:password_server
PASSCT=pass:password_client

# OpenSSL 3.0 will support -copy_extensions argument and this will
# not be necessary. But until then...
# https://github.com/openssl/openssl/pull/13711
if [[ ! -f openssl.cnf ]]; then
  cp -f /etc/pki/tls/openssl.cnf . || true
  cp -f /usr/lib/ssl/openssl.cnf . || true
  sed -i '/\[ usr_cert \]/a \
subjectAltName=${ENV::SAN}' openssl.cnf
  sed -i '/\[ usr_cert \]/a \
extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection' openssl.cnf
fi

# ca.crt
if [[ -f ca.crt ]]; then
  echo "CA found, not overwriting..."
else
  openssl genrsa -passout $PASSCA -des3 -out ca.key 4096
  openssl req -passin $PASSCA -new -x509 -days $DAYS \
    -key ca.key -out ca.crt -subj "$SUBJECT/CN=${CA_CN}"
  openssl x509 -purpose -in ca.crt
  openssl x509 -in ca.crt -out ca.pem -outform PEM
fi

# server.crt
export SAN="DNS:$SERVER_CN, DNS:$SERVER_ALIAS"
if [[ -f server.crt ]]; then
  echo "Server cert found, not overwriting..."
else
  openssl genrsa -passout $PASSSV -des3 -out server.key 4096
  openssl req -passin $PASSSV -new -key server.key -out server.csr \
    -subj "$SUBJECT/CN=${SERVER_CN}" \
    -addext "subjectAltName=$SAN" -addext "extendedKeyUsage=serverAuth"
  openssl x509 -req -passin $PASSCA -extfile ./openssl.cnf \
    -extensions usr_cert -days $DAYS -in server.csr \
    -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
    #-copy_extensions
  openssl x509 -purpose -in server.crt
  openssl rsa -passin $PASSSV -in server.key -out server.key
  openssl x509 -in server.crt -out server.pem -outform PEM
fi

# client.crt
export SAN="DNS:$CLIENT_CN, DNS:$CLIENT_ALIAS"
CLIENT="client-$CLIENT_CN"
openssl genrsa -passout $PASSCT -des3 -out $CLIENT.key 4096
openssl req -passin $PASSCT -new -key $CLIENT.key \
  -out $CLIENT.csr -subj "$SUBJECT/CN=${CLIENT_CN}"
openssl x509 -req -passin $PASSCA -days $DAYS \
  -extfile ./openssl.cnf -extensions usr_cert \
  -in $CLIENT.csr -CA ca.crt -CAkey ca.key -set_serial $RANDOM -out $CLIENT.crt
openssl x509 -purpose -in $CLIENT.crt
openssl rsa -passin $PASSCT -in $CLIENT.key -out $CLIENT.key
openssl x509 -in $CLIENT.crt -out $CLIENT.pem -outform PEM

# print and verify
openssl x509 -in ca.crt -text -out ca.txt
openssl x509 -in server.crt -text -out server.txt
openssl x509 -in $CLIENT.crt -text -out $CLIENT.txt
openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt $CLIENT.crt
