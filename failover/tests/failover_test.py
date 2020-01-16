import os
import tempfile
import unittest
import subprocess

script_path = os.path.dirname(os.path.realpath(__file__))
vagrant_path = os.path.realpath(script_path + "../../../tools/testlab-2isp")

class failover_UnitTests(unittest.TestCase):
    def upload_settings(self, custom_settings={}, no_default_settings=False):
        default_settings = {
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverWan1DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]",
            "failoverWan2DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]"
        }
        settings = {} if no_default_settings else default_settings
        settings.update(custom_settings)

        with open(self.temp_settings_file, "w") as f:
            f.write(":foreach fVar in=[/system script environment find name~\"failover\"] do={/system script environment remove $fVar }\n")
            f.write("if ([:len [/system script find name=failover_settings]] != 0) do={ /system script remove failover_settings }\n")
            f.write("/system script add name=failover_settings source=\"### test settings\\r\\\n")
            for setting_name, setting_value in settings.items():
                f.write("    \\n:global {} {}\\r\\\n".format(setting_name, setting_value))
            f.write("    \\n\"\n")

        subprocess.check_call(("scp", "-F", self.vagrant_ssh_config,
            self.temp_settings_file, "router:write_failover_settings.rsc"))

        subprocess.check_call(("vagrant", "ssh", "router", "--", "/import",
            "write_failover_settings.rsc"),
            cwd=vagrant_path
        )

    def run_failover_script(self):
        output = subprocess.check_output(("vagrant", "ssh", "router", "--",
            "/import", "failover_check.rsc"),
            cwd=vagrant_path
        )
        # for line in output.decode("utf-8").splitlines():
        #     print(line)
        return output.decode("utf-8").splitlines()

    def setup_class(self):
        vm_is_running = False
        output = subprocess.check_output("vagrant status router --machine-readable", shell=True, cwd=vagrant_path)
        for line in output.decode("utf-8").splitlines():
            status_values = line.split(",")
            if (status_values[1] == "router") and (status_values[3] == "running"):
                vm_is_running = True
        if not vm_is_running:
            raise Exception("VM 'router' is not runnig. Bring it up using "
                "'vagrant up' command in {}".format(vagrant_path))

        fd, self.vagrant_ssh_config = tempfile.mkstemp()
        os.close(fd)
        subprocess.check_call("vagrant ssh-config router > {}".format(self.vagrant_ssh_config),
            shell=True, cwd=vagrant_path)

        failover_script_path = os.path.realpath(script_path + "../../failover_check.rsc")
        subprocess.check_call(("scp", "-F", self.vagrant_ssh_config,
            failover_script_path, "router:"))

        fd, self.temp_settings_file = tempfile.mkstemp()
        os.close(fd)

    def teardown_class(self):
        os.remove(self.temp_settings_file)
        os.remove(self.vagrant_ssh_config)


    def test_dummy(self):
        self.upload_settings(custom_settings={"ccc": "3"})
        # self.upload_settings(custom_settings={"ccc": "3"}, no_default_settings=True)
        output = self.run_failover_script()
        self.assertIn("wan21 test results [failed/threshold/total]: 0/2/6", output)
