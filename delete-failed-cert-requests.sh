#!/bin/bash

set -euo pipefail

# kubectl get certificaterequests -A -o json | \
#   jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="False")) | "\(.metadata.name) \t \(.metadata.namespace)"' | \
#   awk '{ print "kubectl delete certificaterequests", $1, "-n", $2 }' | \
#   bash

export APISERVER=https://kubernetes.default.svc
export SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
export TOKEN=$(cat ${SERVICEACCOUNT}/token)
export CACERT=${SERVICEACCOUNT}/ca.crt
if [ -z "$RENEW_INTERVAL" ]; then
  RENEW_INTERVAL="5m"
fi

function request_apiserver() {
  curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X ${1} "${APISERVER}${2}"
}
export -f request_apiserver

function delete_failed_certificate_requests() {
  request_apiserver GET /apis/cert-manager.io/v1/certificaterequests | \
    jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="False")) | "\(.metadata.namespace) \t \(.metadata.name)"' | \
    awk '{ printf "request_apiserver DELETE /apis/cert-manager.io/v1/namespaces/%s/certificaterequests/%s\n", $1, $2 }' | \
    bash
}

while true; do
  echo "Deleting pending certificate requests..."
  delete_failed_certificate_requests;
  sleep $RENEW_INTERVAL;
done;
