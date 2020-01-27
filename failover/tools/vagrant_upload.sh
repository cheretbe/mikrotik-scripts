#!/bin/bash

#set -euo pipefail
set -o pipefail

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
  echo >&2 "This script needs to be sourced to run correctly"
  exit 1
fi

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)
if [ -z ${1+x} ]; then
  testlab_dir=$(cd ${project_dir}/../tools/testlab-2isp; pwd)
else
  testlab_dir=${1}
fi

echo "Varant testlab path: ${testlab_dir}"

if [ -z ${AO_MT_VAGRANT_VM+x} ]; then
  echo "Reading VM list"
  v_status=$(cd ${testlab_dir}; vagrant status 2>&1)
  if [ $? -ne 0 ]; then
    echo $v_status
    return
  fi
  vm_list=$(cd ${testlab_dir}; vagrant status --machine-readable | grep "state,running" | cut -d',' -f 2)
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
  (cd ${testlab_dir}; vagrant ssh-config ${AO_MT_VAGRANT_VM} > ${AO_MT_VAGRANT_CONFIG})
  export AO_MT_VAGRANT_CONFIG
fi


echo "Creating 'failover' directory"
# There is no direct way to create a directory. This is an ugly hack
# https://forum.mikrotik.com/viewtopic.php?t=139071
(cd ${testlab_dir}; vagrant ssh ${AO_MT_VAGRANT_VM} -- '/tool fetch dst-path="/failover/dummy" url="http://127.0.0.1:80/" keep-result=no')

echo "Uploading failover_check.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/failover_check.rsc" ${AO_MT_VAGRANT_VM}:failover/

echo "Uploading version.txt"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/version.txt" ${AO_MT_VAGRANT_VM}:failover/

echo "Uploading write_test_settings.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/tools/write_test_settings.rsc" ${AO_MT_VAGRANT_VM}:failover/

echo "Uploading setup.rsc"
scp -F ${AO_MT_VAGRANT_CONFIG} "${project_dir}/failover_setup.rsc" ${AO_MT_VAGRANT_VM}:

echo "Running '/import write_test_settings.rsc'"
(cd ${testlab_dir}; vagrant ssh ${AO_MT_VAGRANT_VM} -- /import failover/write_test_settings.rsc)

read -p "Run failover_check.rsc? [Y/n]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ $REPLY = "" ]] ; then
  echo "Running '/import failover_check.rsc'"
  (cd ${testlab_dir}; vagrant ssh ${AO_MT_VAGRANT_VM} -- /import failover/failover_check.rsc)
fi