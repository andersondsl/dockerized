#!/bin/bash
# Author: Zhang Huangbin <zhb@iredmail.org>

#
# This file is managed by iRedMail Team <support@iredmail.org> with Ansible,
# please do __NOT__ modify it manually.
#

. /docker/entrypoints/functions.sh

CONF="/etc/amavisd.conf"
SPOOL_DIR="/var/spool/amavisd"
TEMP_DIR="/var/spool/amavisd/tmp"
QUARANTINE_DIR="/var/spool/amavisd/quarantine"
DB_DIR="/var/spool/amavisd/db"
VAR_DIR="/var/spool/amavisd/var"

DKIM_DIR="/opt/iredmail/custom/amavisd/dkim"
DKIM_KEY="${DKIM_DIR}/${FIRST_MAIL_DOMAIN}.pem"

CUSTOM_CONF_DIR="/opt/iredmail/custom/amavisd"

# ClamAV
CLAMAV_DB_DIR="/var/lib/clamav"

for d in ${SPOOL_DIR} ${TEMP_DIR} ${QUARANTINE_DIR} ${DB_DIR} ${VAR_DIR}; do
    [[ -d ${d} ]] || install -d -o amavis -g amavis -m 0770 ${d}
done

[[ -d ${CUSTOM_CONF_DIR} ]] || install -d -o root -g root -m 0555 ${CUSTOM_CONF_DIR}

# Assign clamav daemon user to Amavisd group, so that it has permission to scan message.
addgroup clamav amavis

# Generate DKIM key for first mail domain.
install -d -o amavis -g amavis -m 0770 ${DKIM_DIR}
[[ -f ${DKIM_KEY} ]] || /usr/sbin/amavisd genrsa ${DKIM_KEY} 1024
chown amavis:amavis ${DKIM_KEY}
chmod 0400 ${DKIM_KEY}

# ClamAV
install -d -o clamav -g clamav -m 0755 ${CLAMAV_DB_DIR}

# Update parameters.
${CMD_SED} "s#PH_HOSTNAME#${HOSTNAME}#g" ${CONF}

${CMD_SED} "s#PH_SQL_SERVER_ADDRESS#${SQL_SERVER_ADDRESS}#g" ${CONF}
${CMD_SED} "s#PH_SQL_SERVER_PORT#${SQL_SERVER_PORT}#g" ${CONF}
${CMD_SED} "s#PH_AMAVISD_DB_PASSWORD#${AMAVISD_DB_PASSWORD}#g" ${CONF}

LOG "Run 'sa-update' (required by Amavisd)."
sa-update -v

if [[ ! -f "${CLAMAV_DB_DIR}/main.cvd" ]] && [[ ! -f "${CLAMAV_DB_DIR}/bytecode.cvd" ]]; then
    LOG "Run 'freshclam' (required by ClamAV)."
    freshclam
fi
