#!/bin/bash
#
# Copyright 2017 StreamSets Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e
echo "$@"
echo "Entering entry point"
# We translate environment variables to sdc.properties and rewrite them.
set_conf() {
  if [ $# -ne 2 ]; then
    echo "set_conf requires two arguments: <key> <value>"
    exit 1
  fi

  if [ -z "$SDC_CONF" ]; then
    echo "SDC_CONF is not set."
    exit 1
  fi

  sed -i 's|^#\?\('"$1"'=\).*|\1'"$2"'|' "${SDC_CONF}/sdc.properties"
}
echo "getting hostname"
export INSTANCE_HOSTNAME=$(curl -s http://rancher-metadata/latest/self/host/name)
export HTTP_PORT=$(curl http://rancher-metadata/latest/self/service/ports/0 | cut -d":" -f1)


if [ -z $INSTANCE_HOSTNAME ]
then
  echo "Failed to get host's hostname from rancher-metadata API." >> /dev/stderr
  export INSTANCE_HOSTNAME=$(cat /etc/hostname)
fi

if [ -z $HTTP_PORT ]
then
  echo "Failed to get host's hostname from rancher-metadata API." >> /dev/stderr
  export HTTP_PORT=18630
fi
    
echo "HOSTNAME SET ${INSTANCE_HOSTNAME}"
echo "HTTP PORT SET ${HTTP_PORT}"

#echo ${INSTANCE_HOSTNAME} > /etc/hostname
#curl http://rancher-metadata/latest/self/host/name > ~/hosts.new


sed -i '/<hostname>:<port>/s/^#//g' /etc/sdc/sdc.properties
sed -i "/<hostname>:<port>/c sdc.base.http.url=http://${INSTANCE_HOSTNAME}:${HTTP_PORT}" /etc/sdc/sdc.properties

# Install libraries during an upgrade

if [[ ! -z $ADD_LIBS ]];
then 
  $SDC_DIST/bin/streamsets stagelibs -install=$ADD_LIBS ; 
fi

# In some environments such as Marathon $HOST and $PORT0 can be used to
# determine the correct external URL to reach SDC.

echo "setting config"
#echo $START_ARGS
if [ ! -z "$HOST" ] && [ ! -z "$PORT0" ] && [ -z "$SDC_CONF_SDC_BASE_HTTP_URL" ]; then
  export SDC_CONF_SDC_BASE_HTTP_URL="http://${INSTANCE_HOSTNAME}:${PORT0}"
fi


#echo ${START_ARGS}
for e in $(env); do
  key=${e%=*}
  value=${e#*=}
  if [[ $key == SDC_CONF_* ]]; then
    lowercase=$(echo $key | tr '[:upper:]' '[:lower:]')
    key=$(echo ${lowercase#*sdc_conf_} | sed 's|_|.|g')
    set_conf $key $value
  fi
done


#echo $USE_LDAP

if [ "$USE_LDAP" = "true" ];
then
        echo "Configuring LDAP parameters"
        sed -i -e "s/http.authentication.login.module=file/http.authentication.login.module=ldap/" /etc/sdc/sdc.properties
        sed -i  "/http.authentication.ldap.role.mapping=/c\http.authentication.ldap.role.mapping=${SDC_CONF_HTTP_AUTHENTICATION_LDAP_ROLE_MAPPING}" /etc/sdc/sdc.properties
        sed -i "/debug=/c\debug="'"true"'"" /etc/sdc/ldap-login.conf
        sed -i '/hostname=/c\hostname="'"${LDAP_HOSTNAME}"'"' /etc/sdc/ldap-login.conf
        sed -i '/bindDn=/c\bindDn="'"${LDAP_BINDN}"'"' /etc/sdc/ldap-login.conf
        sed -i "/forceBindingLogin=/c\forceBindingLogin="'"true"'"" /etc/sdc/ldap-login.conf
        sed -i '/userBaseDn=/c\userBaseDn="'"${LDAP_USERBASEDN}"'"' /etc/sdc/ldap-login.conf
        sed -i '/userIdAttribute=/c\userIdAttribute="'"${LDAP_USERIDATTRIBUTE}"'"' /etc/sdc/ldap-login.conf
        sed -i '/userObjectClass=/c\userObjectClass="'"${LDAP_USEROBJECTCLASS}"'"' /etc/sdc/ldap-login.conf
        sed -i '/userFilter=/c\userFilter="'"${LDAP_USERFILTER}"'"' /etc/sdc/ldap-login.conf
        sed -i '/roleBaseDn=/c\roleBaseDn="'"${LDAP_ROLEBASEDN}"'"' /etc/sdc/ldap-login.conf
        sed -i '/roleObjectClass=/c\roleObjectClass="'"${LDAP_ROLEOBJECTCLASS}"'"' /etc/sdc/ldap-login.conf
        sed -i "/password/c\\${LDAP_BINDPASSWORD}" /etc/sdc/ldap-bind-password.txt
		sed -i '/SDC_JAVA_OPTS="-Xmx/c\export SDC_JAVA_OPTS="'"${SDC_JAVA_OPTS}"'"' ${SDC_DIST}/libexec/sdc-env.sh
else
        echo "Using file default credentials of streamsets"
fi

#exec "${SDC_DIST}/bin/streamsets" "$@"

exec "${SDC_DIST}/bin/streamsets" "dc"
