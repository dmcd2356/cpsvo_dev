#!/bin/bash

# This creates a self-signed certificate for implementing HTTPS.

# path where all development files to use are kept
# this makes it a requirement to have a development directory and to be running this script from it.
VALUE=`pwd`
if [ "${VALUE##*/}" != "scripts" ]; then
  echo "ERROR: This script must be run from the 'scripts' subfolder of your drupal development folder."
  echo "       For info on the structure of this folder, re-enter the command with the -h option."
  exit 1
fi
# this sets it to parent dir of the scripts dir
DRUPAL_DEV="${VALUE%/*}"

# create a directory to contain the files needed for generating a certificate
DRUPAL_CERT="${DRUPAL_DEV}/certificate"
mkdir -p ${DRUPAL_CERT}
cd ${DRUPAL_CERT}

# create a passphrase file in that directory
echo SillyPassword > passphrase.txt

# create a README file to define the contents of this directory
FILENAME=README
if [ ! -f ${FILENAME} ]; then
  echo "- creating ${FILENAME}"
  touch ${FILENAME}
  echo "This directory should, at a minimum, contain the following certificate related files:" >> ${FILENAME}
  echo "" >> ${FILENAME}
  echo "ssl-cert-snakeoil.key - the public key used in creating the certificate" >> ${FILENAME}
  echo "ssl-cert-snakeoil.pem - the self-signed certificate file" >> ${FILENAME}
fi

# create the file localdomain.csr.cnf (in the same directory) that consists of the following data:
FILENAME=localdomain.csr.cnf
if [ ! -f ${FILENAME} ]; then
  echo "- creating configuration file: ${FILENAME}"
  touch ${FILENAME}
  echo "[req]" >> ${FILENAME}
  echo "default_bits = 2048" >> ${FILENAME}
  echo "prompt = no" >> ${FILENAME}
  echo "default_md = sha256" >> ${FILENAME}
  echo "distinguished_name = dn" >> ${FILENAME}
  echo "" >> ${FILENAME}
  echo "[dn]" >> ${FILENAME}
  echo "C=US" >> ${FILENAME}
  echo "ST=Tennessee" >> ${FILENAME}
  echo "L=Nashville" >> ${FILENAME}
  echo "O=Vanderbilt University" >> ${FILENAME}
  echo "OU=ISIS" >> ${FILENAME}
  echo "emailAddress=whocares@my.org" >> ${FILENAME}
  echo "CN = localhost" >> ${FILENAME}
fi

# create another configuration file called localdomain.v3.ext consisting of:
FILENAME=localdomain.v3.ext
if [ ! -f ${FILENAME} ]; then
  echo "- creating configuration file: ${FILENAME}"
  touch ${FILENAME}
  echo "authorityKeyIdentifier=keyid,issuer" >> ${FILENAME}
  echo "basicConstraints=CA:FALSE" >> ${FILENAME}
  echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" >> ${FILENAME}
  echo "subjectAltName = @alt_names" >> ${FILENAME}
  echo "" >> ${FILENAME}
  echo "[alt_names]" >> ${FILENAME}
  echo "DNS.1 = localhost" >> ${FILENAME}
fi

# create a Certificate Signing Request:
# - openssl rand   creates the .rnd file needed for random number generation
# - openssl genrsa creates a public/private key pair (localdomain.secure.key) from the passphrase
# - openssl rsa    creates an public (non-passphrase) version of the key (localdomain.insecure.key)
# - openssl req    creates a Certificate Signing Request file (localdomain.csr) using public key
echo "- generating public and private key pair: localdomain.insecure.key & localdomain.secure.key"
openssl rand -out /home/$USER/.rnd -hex 256
openssl genrsa -des3 -out localdomain.secure.key -passout file:passphrase.txt 2048
openssl rsa -in localdomain.secure.key -out localdomain.insecure.key -passin file:passphrase.txt
echo "- generating Certificate Signing Request: localdomain.csr"
openssl req -new -sha256 -nodes -key localdomain.insecure.key -out localdomain.csr -config localdomain.csr.cnf

# generate Root SSL Certificate (CA Certificate)
echo "- generating Root SSL Certificate: cacert.pem"
openssl genrsa -des3 -out rootca.secure.key -passout file:passphrase.txt 2048
openssl rsa -in rootca.secure.key -out rootca.insecure.key -passin file:passphrase.txt
openssl req -new -x509 -days 3650 -nodes -key rootca.insecure.key -sha256 -out cacert.pem -config localdomain.csr.cnf

# generate the self-signed certificate
echo "- generating self-signed Certificate: localdomain.crt"
openssl x509 -req -sha256 -days 365 -in localdomain.csr -CA cacert.pem -CAkey rootca.insecure.key -CAcreateserial -extfile localdomain.v3.ext -out localdomain.crt

# rename the certificate and public key files
cp localdomain.crt ssl-cert-snakeoil.pem
cp localdomain.insecure.key ssl-cert-snakeoil.key
