user default off
user ${REDIS_RW_USER_NAME} on >${REDIS_RW_USER_PASSWORD} ~* +@all -@dangerous
user ${REDIS_METRICS_USER_NAME} on >${REDIS_METRICS_USER_PASSWORD} -@all ~* &* +ping +info +role +dbsize +time +lastsave +client|list +client|info +slowlog|get +slowlog|len +latency|doctor +latency|graph +latency|latest +latency|histogram +memory|stats