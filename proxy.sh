#!/bin/bash
set -e
set -o pipefail

DNS_SERVER=223.5.5.5

if [ -z "$DOMAIN" ]; then
  echo "No DOMAIN specified."
  exit 1
fi

if [ -z "$SOCKS_ADDR" ] || [ -z "$HTTP_ADDR" ]; then
  echo "Neither SOCKS_ADDR nor HTTP_ADDR specified."
  exit 1
fi

if [ ! -z "$SOCKS_ADDR" ]; then
  SOCKS_PORT=${SOCKS_PORT:-1080}
else
  HTTP_PORT=${HTTP_PORT:-8118}
fi

echo -e "[supervisord]\nnodaemon = true\n\n" > /etc/supervisord.conf

if [ ! -z "$SOCKS_ADDR"]; then
  echo "Use SOCKS proxy: $SOCKS_ADDR:$SOCKS_PORT"
  HTTP_ADDR="127.0.0.1"
  HTTP_PORT="8118"
  COMMAND="delegated -P$HTTP_PORT SERVER=http SOCKS=$SOCKS_ADDR:$SOCKS_PORT REMITTABLE=\"*\" -f"
  echo -e "[program:delegated]\ncommand=$COMMAND\nautorestart=true\n\n" >> /etc/supervisord.conf
else
  echo "Use HTTP proxy: $HTTP_ADDR:$HTTP_PORT"
fi

IP=$(dig +short @$DNS_SERVER $DOMAIN | awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}' | grep . | head -n 1)
if [ -z "$IP" ]; then
  echo "Unable to resolve IP addresses for $DOMAIN"
  exit 1
fi
echo "$DOMAIN resolved: $IP"

for PORT in $@; do
  COMMAND="socat TCP4-LISTEN:$PORT,fork,reuseaddr PROXY:$HTTP_ADDR:$IP:$PORT,proxyport=$HTTP_PORT"
  echo -e "[program:port$PORT]\ncommand=$COMMAND\nautorestart=true\n\n" >> /etc/supervisord.conf
done

echo "Starting supervisord..."
supervisord

