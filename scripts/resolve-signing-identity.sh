#!/bin/bash
set -euo pipefail

CONFIG="${1:-debug}"
SIGN_IDENTITY="${MNEMO_CODESIGN_IDENTITY:-}"

case "$CONFIG" in
  debug|release) ;;
  *)
    echo "error: build configuration must be debug or release" >&2
    exit 1
    ;;
esac

if [ "$SIGN_IDENTITY" = "-" ]; then
  if [ "$CONFIG" = "release" ]; then
    echo "error: release packaging requires a stable Apple signing identity" >&2
    exit 1
  fi
  if [ "${MNEMO_ALLOW_ADHOC_SIGNING:-0}" != "1" ]; then
    echo "error: set MNEMO_ALLOW_ADHOC_SIGNING=1 for an ad-hoc debug build" >&2
    exit 1
  fi
  printf '%s\n' "$SIGN_IDENTITY"
  exit 0
fi

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk '/Apple Development/ { print $2; exit }')"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  if [ "$CONFIG" = "release" ]; then
    echo "error: release packaging requires a stable Apple signing identity" >&2
    exit 1
  fi
  if [ "${MNEMO_ALLOW_ADHOC_SIGNING:-0}" != "1" ]; then
    echo "error: set MNEMO_ALLOW_ADHOC_SIGNING=1 for an ad-hoc debug build" >&2
    exit 1
  fi
  SIGN_IDENTITY="-"
fi

printf '%s\n' "$SIGN_IDENTITY"
