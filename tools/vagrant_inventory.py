#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import yaml

# https://www.jeffgeerling.com/blog/creating-custom-dynamic-inventories-ansible

def run_vagrant_cmd(cmd):
    result = []

    # https://www.vagrantup.com/docs/cli/machine-readable
    # timestamp,target,type,data...
    for line in subprocess.check_output(
            (["vagrant"] + cmd + ["--machine-readable"]),
            universal_newlines=True
    ).splitlines():
        result.append(line.split(","))

    return result

def get_config_values(vm_name, config_cmd, config_mapping):
    vagrant_config = []
    for config_values in run_vagrant_cmd([config_cmd, vm_name]):
        if (len(config_values) > 3) and config_values[2] == config_cmd:
            # We split on escaped newline, not a newline character itself, since
            # newlines within the output are replaced with standard escape sequence
            vagrant_config = config_values[3].split("\\n")
    result = {}
    for config_line in vagrant_config:
        config_values = config_line.lstrip().split(" ", 1)
        ansible_var = config_mapping.get(config_values[0], None)
        if ansible_var:
            result[ansible_var] = config_values[1]
    return result

def get_windows_vars(vm_name):
    result = {
        "ansible_connection": "winrm",
        "ansible_winrm_transport": "ntlm",
        "ansible_winrm_scheme": "http"
    }
    result.update(
        get_config_values(
            vm_name=vm_name,
            config_cmd="winrm-config",
            config_mapping={
                "HostName": "ansible_host",
                "User": "ansible_user",
                "Password": "ansible_password",
                "Port": "ansible_port"
            }
        )
    )
    return result

def get_linux_vars(vm_name):
    result = {
        "ansible_host_key_checking": False
    }
    result.update(
        get_config_values(
            vm_name=vm_name,
            config_cmd="ssh-config",
            config_mapping={
                "HostName": "ansible_host",
                "User": "ansible_user",
                "IdentityFile": "ansible_ssh_private_key_file",
                "Port": "ansible_port"
            }
        )
    )
    return result


def build_vagrant_inventory():
    vms = []

    vagrant_status = run_vagrant_cmd(["status"])
    for status_values in vagrant_status:
        if status_values[2] == "metadata" and status_values[3] == "provider":
            vms.append({"name": status_values[1]})

    for vm in vms:
        for status_values in vagrant_status:
            if status_values[1] == vm["name"] and status_values[2] == "state":
                vm["running"] = (status_values[3] == "running")

    # Trying to detect Windows VMs, assuming that if WinRM ports (5985, 5986) are
    # being forwarded, it's Windows
    for vm in vms:
        vm["is_windows"] = False
        for port_values in run_vagrant_cmd(["port", vm["name"]]):
            if port_values[1] == vm["name"] and port_values[2] == "forwarded_port":
                if port_values[3] in ("5985", "5986"):
                    vm["is_windows"] = True

    inventory = {
        "all": { "hosts": [],
            "vars": {
                "ansible_user": "vagrant"
            }
        },
        "_meta": {
            "hostvars": {}
        }
    }
    for vm in vms:
        if vm["running"]:
            inventory["all"]["hosts"].append(vm["name"])
            if vm["is_windows"]:
                inventory["_meta"]["hostvars"][vm["name"]] = get_windows_vars(vm["name"])
            else:
                inventory["_meta"]["hostvars"][vm["name"]] = get_linux_vars(vm["name"])
            if os.path.isfile(f"host_vars/{vm['name']}.yml"):
                with open(f"host_vars/{vm['name']}.yml") as vars_f:
                    inventory["_meta"]["hostvars"][vm["name"]].update(yaml.safe_load(vars_f))

    return inventory

def main(args):
    inventory = {'_meta': {'hostvars': {}}}
    # No need to implement --host since we return _meta info in '--list'
    if args.list:
        inventory = build_vagrant_inventory()
    print(json.dumps(inventory))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("--list", action="store_true")
    parser.add_argument("--host", action="store")

    args = parser.parse_args()
    main(args)
