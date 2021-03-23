#!/bin/bash -e

# server certificate common name
SERVER_CN=${1:-nuc}

# server certificate alias (required: provide a dummy one)
SERVER_ALIAS=${2:-_does_not_work_yet_see_below_}

# client certificate common name
CLIENT_CN=${2:-mone}

SUBJECT="/C=US/ST=CA/O=Example.com"
CA_CN="Example CA TESTING"
DAYS=9999
PASSCA=pass:password_ca
PASSSV=pass:password_server
PASSCT=pass:password_client

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
if [[ -f server.crt ]]; then
  echo "Server cert found, not overwriting..."
else
  openssl genrsa -passout $PASSSV -des3 -out server.key 4096
  openssl req -passin $PASSSV -new -key server.key -out server.csr \
    -subj "$SUBJECT/CN=${SERVER_CN}" -addext "subjectAltName=DNS:$SERVER_ALIAS"
  openssl x509 -req -passin $PASSCA -extfile /etc/pki/tls/openssl.cnf \
    -extensions usr_cert -days $DAYS -in server.csr \
    -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
    # the following argument was merged into the project Jan 2021
    # and uncommenting it will make alias to be included
    # https://github.com/openssl/openssl/pull/13711
    #-copy_extensions
  openssl x509 -purpose -in server.crt
  openssl rsa -passin $PASSSV -in server.key -out server.key
  openssl x509 -in server.crt -out server.pem -outform PEM
fi

# client.crt
CLIENT="client-$CLIENT_CN"
openssl genrsa -passout $PASSCT -des3 -out $CLIENT.key 4096
openssl req -passin $PASSCT -new -key $CLIENT.key \
  -out $CLIENT.csr -subj "$SUBJECT/CN=${CLIENT_CN}"
openssl x509 -req -passin $PASSCA -days $DAYS \
  -extfile /etc/pki/tls/openssl.cnf -extensions usr_cert \
  -in $CLIENT.csr -CA ca.crt -CAkey ca.key -set_serial $RANDOM -out $CLIENT.crt
openssl x509 -purpose -in $CLIENT.crt
openssl rsa -passin $PASSCT -in $CLIENT.key -out $CLIENT.key
openssl x509 -in $CLIENT.crt -out $CLIENT.pem -outform PEM

# print and verify
openssl x509 -in ca.crt -text -noout
openssl x509 -in server.crt -text -noout
openssl x509 -in $CLIENT.crt -text -noout
openssl verify -CAfile ca.crt server.crt
openssl verify -CAfile ca.crt $CLIENT.crt
