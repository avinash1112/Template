#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nodejs/lib/00-helpers.sh


# Final handoff
exec "$@"
