#!/bin/bash
set -e
set -o pipefail

_term() {
  echo "Exiting..."
  kill -TERM "$child" 2>/dev/null
}

trap _term SIGTERM
trap _term SIGINT

DNS_SERVER=${DNS_SERVER:-10.10.0.21}

echo "HTTP_PROXY=$HTTP_PROXY"
echo "HTTPS_PROXY=$HTTPS_PROXY"
echo "NO_PROXY=$NO_PROXY"
echo "DNS_SERVER=$DNS_SERVER"

if [ -z "$DOMAIN" ]; then
  echo "No DOMAIN specified."
  exit 1
fi

echo -e "[supervisord]\nnodaemon = true\nuser = root\n\n" > /etc/supervisord.conf

if [ -z "$DIRECT" ]; then
  if [ -z "$SOCKS_ADDR" ] && [ -z "$HTTP_ADDR" ]; then
    echo "Neither SOCKS_ADDR nor HTTP_ADDR specified."
    exit 1
  fi

  if [ ! -z "$SOCKS_ADDR" ]; then
    SOCKS_PORT=${SOCKS_PORT:-1080}
    echo "Use SOCKS proxy: $SOCKS_ADDR:$SOCKS_PORT"
    HTTP_ADDR="127.0.0.1"
    HTTP_PORT="8118"
    COMMAND="delegated -P$HTTP_PORT SERVER=http SOCKS=$SOCKS_ADDR:$SOCKS_PORT REMITTABLE=\"*\" -f"
    echo -e "[program:delegated]\ncommand=$COMMAND\nautorestart=true\n\n" >> /etc/supervisord.conf
  else
    HTTP_PORT=${HTTP_PORT:-8118}
    echo "Use HTTP proxy: $HTTP_ADDR:$HTTP_PORT"
  fi
else
  echo "Use direct mode."
fi

# echo "Resolving $DOMAIN..."
# export IP_ADDR="$(dig +short @$DNS_SERVER $DOMAIN | awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}' | grep . | head -n 1)"
# if [ -z "$IP_ADDR" ]; then
#   echo "Unable to resolve IP addresses for $DOMAIN"
#   exit 1
# fi
# echo "$DOMAIN resolved: $IP_ADDR"

for PORT in $@; do
  if [ -z "$DIRECT" ]; then
    COMMAND="socat TCP4-LISTEN:$PORT,fork,reuseaddr PROXY:$HTTP_ADDR:$DOMAIN:$PORT,proxyport=$HTTP_PORT"
  else
    COMMAND="socat TCP4-LISTEN:$PORT,fork,reuseaddr TCP:$DOMAIN:$PORT"
  fi
  echo -e "[program:port$PORT]\ncommand=$COMMAND\nautorestart=true\n\n" >> /etc/supervisord.conf
done

echo "Starting supervisord..."
supervisord -c /etc/supervisord.conf &

child=$!
wait "$child"

