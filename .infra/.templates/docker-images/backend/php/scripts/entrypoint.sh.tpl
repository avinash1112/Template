#!/bin/bash
set -Eeuo pipefail

# Load helpers
source /opt/php/lib/00-helpers.sh

# Variables
app_dir="/var/www/html"
artisan="${app_dir}/artisan"


# If a laravel project
if is_laravel_project "${artisan}"; then

  # Run migrations
  php "${artisan}" migrate

  # Laravel's optimization
  laravel_clear "${artisan}"
  laravel_optimize "${artisan}"
  
fi

# Final handoff
exec "$@"
