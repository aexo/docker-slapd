#!/bin/sh

set -eu

status () {
  echo "---> ${@}" >&2
}

set -x
: LDAP_ROOTPASS=${LDAP_ROOTPASS}
: LDAP_DOMAIN=${LDAP_DOMAIN}
: LDAP_ORGANISATION=${LDAP_ORGANISATION}


ln -s /data/ldap/slapd.d /etc/ldap/slapd.d
ln -s /data/ldap/schema /etc/ldap/schema
ln -s /data/ldap/config /var/lib/ldap

chown openldap:openldap /data/ldap -R

if [ ! -e /data/ldap/docker_bootstrapped ]; then
  status "configuring slapd for first run"

  cp /backup/ldap/slapd.d /data/ldap -r
  cp /backup/ldap/schema /data/ldap -r
  cp /backup/ldap/config /data/ldap/config -r

  cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_ROOTPASS}
slapd slapd/internal/adminpw password ${LDAP_ROOTPASS}
slapd slapd/password2 password ${LDAP_ROOTPASS}
slapd slapd/password1 password ${LDAP_ROOTPASS}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string HDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

  dpkg-reconfigure -f noninteractive slapd

  touch /data/ldap/docker_bootstrapped
else
  status "found already-configured slapd"
fi

status "starting slapd"
set -x
exec /usr/sbin/slapd -h "ldap:///" -u openldap -g openldap -d 0
