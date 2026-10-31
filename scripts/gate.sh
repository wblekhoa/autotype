#!/bin/bash
# AutoType gate for the JAK product-gate hooks (~/JAK/hq/githooks/gate.mjs, hq/plans/product-gates.md).
# --fast (pre-commit): typecheck AutoType.swift with build.sh's flags (errors only); nothing is built.
# full (pre-push): ./verify.sh — build and package in an isolated HOME; without --full, so no window steals focus.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = --fast ]; then
  exec swiftc -typecheck -suppress-warnings -swift-version 5 -parse-as-library AutoType.swift
fi
exec ./verify.sh
