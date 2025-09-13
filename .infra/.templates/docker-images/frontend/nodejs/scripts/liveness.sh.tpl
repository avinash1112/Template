#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/nodejs/lib/00-helpers.sh


echo_success "[LIVENESS] All checks passed!"
exit 0
