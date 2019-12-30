#!/bin/bash

#set -euo pipefail
set -o pipefail

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo >&2 "This script needs to be sourced to run correctly"
  exit 1
fi

if [ -z ${AO_MT_VAGRANT_VM+x} ]; then
  echo "Reading VM list"
  v_status=$(vagrant status 2>&1)
  if [ $? -ne 0 ]; then
    echo $v_status
    return
  fi
  vm_list=$(vagrant status --machine-readable | grep "state,running" | cut -d',' -f 2)
  if [ "${vm_list}" == "" ]; then
    echo >&2 "Make sure at least one VM is running"
    return
  fi

  if [ "${vm_list}" == "default" ]; then
    AO_MT_VAGRANT_VM=default
  else
    PS3="Select VM: "
    select AO_MT_VAGRANT_VM in ${vm_list}
    do
      break
    done
  fi
  export AO_MT_VAGRANT_VM
fi

if [ -z ${AO_MT_VAGRANT_CONFIG+x} ]; then
  echo "Creating temporary OpenSSH configuration file"
  AO_MT_VAGRANT_CONFIG=$(mktemp)
  echo "Configuration file path: ${AO_MT_VAGRANT_CONFIG}"
  vagrant ssh-config ${AO_MT_VAGRANT_VM} > ${AO_MT_VAGRANT_CONFIG}
  export AO_MT_VAGRANT_CONFIG
fi

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)

echo "Uploading failover_check.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/failover_check.rsc" ${AO_MT_VAGRANT_VM}:

echo "Uploading failover_settings.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/failover_settings.rsc" ${AO_MT_VAGRANT_VM}:

echo "Uploading setup.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/setup.rsc" ${AO_MT_VAGRANT_VM}: