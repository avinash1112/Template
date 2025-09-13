#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nginx/lib/00-helpers.sh

# Final handoff
exec "$@"
