import os
import tempfile
import time
import unittest
import subprocess

script_path = os.path.dirname(os.path.realpath(__file__))
vagrant_path = os.path.realpath(script_path + "../../../tools/testlab-2isp")

def run_ros_command(ros_command):
    subprocess.check_call("vagrant ssh router -- " + ros_command,
        shell=True, cwd=vagrant_path
    )

class failover_UnitTests(unittest.TestCase):
    def upload_settings(self, custom_settings={}, no_default_settings=False):
        default_settings = {
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverWan1DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]",
            "failoverWan2DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]",
            "failoverPingTargets": "{ 1.1.1.1 }",
            "failoverWan1PingTimeout": "(:totime 00:00:00.055)",
            "failoverWan2PingTimeout": "(:totime 00:00:00.055)",
            "failoverPingTries": "1",
            "failoverMinPingReplies": "1",
            "failoverRecoverCount": "1",
            "failoverMaxFailedHosts": "1"
        }
        settings = {} if no_default_settings else default_settings
        settings.update(custom_settings)
        # print(settings)

        with open(self.temp_settings_file, "w") as f:
            f.write(":foreach fVar in=[/system script environment find name~\"^failover\"] do={/system script environment remove $fVar }\n")
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
        for line in output.decode("utf-8").splitlines():
            print(line)
        return output.decode("utf-8").splitlines()

    def setup_class(self):
        # self.longMessage = False
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

    def assertSubstringIn(self, first, second):
        if not any(first in array_item for array_item in second):
            raise AssertionError("'{}' not found is script output".format(first))


    def test_mandatory_parameters(self):
        # Should fail if failoverWan1PingSrcAddress is not defined
        self.upload_settings(no_default_settings=True)
        output = self.run_failover_script()
        self.assertIn("ERROR: failoverWan1PingSrcAddress parameter is not set", output)

        # Should fail if failoverWan2PingSrcAddress is not defined
        self.upload_settings(no_default_settings=True,
            custom_settings={"failoverWan1PingSrcAddress": "172.19.10.1"})
        output = self.run_failover_script()
        self.assertIn("ERROR: failoverWan2PingSrcAddress parameter is not set", output)

        # Should not fail if both ping source addresses are defined and
        # failoverSwitchRoutes is not set to true
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2"})
        output = self.run_failover_script()
        self.assertSubstringIn("name=failoverWan1PingSrcAddress value=172.19.10.1", output)
        self.assertSubstringIn("name=failoverWan2PingSrcAddress value=172.19.10.2", output)
        self.assertSubstringIn("name=failoverSwitchRoutes value=false", output)
        self.assertIn("Settings have been loaded successfully", output)

        # Should fail if failoverSwitchRoutes is set to true and no default
        # routes to switch are defined
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverSwitchRoutes": "true"})
        output = self.run_failover_script()
        self.assertIn("ERROR: Invalid failoverWan1DefaultRoute value (len=0)", output)
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverSwitchRoutes": "true",
            "failoverWan1DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]"
        })
        output = self.run_failover_script()
        self.assertIn("ERROR: Invalid failoverWan2DefaultRoute value (len=0)", output)

        # Should not fail if failoverSwitchRoutes is set to true and both default
        # routes to switch are defined
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverSwitchRoutes": "true",
            "failoverWan1DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]",
            "failoverWan2DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]"
        })
        output = self.run_failover_script()
        self.assertIn("Settings have been loaded successfully", output)

    def test_default_parameters(self):
        # Should use default values for non-mandatory parameters
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2"})
        output = self.run_failover_script()
        self.assertSubstringIn("name=failoverWan1PingTimeout value=00:00:00.500", output)
        self.assertSubstringIn("name=failoverWan2PingTimeout value=00:00:00.500", output)
        self.assertSubstringIn("name=failoverSwitchRoutes value=false", output)
        self.assertSubstringIn("name=failoverPreferWan2 value=false", output)
        self.assertSubstringIn("name=failoverPingTargets value=1.1.1.1;1.0.0.1;"
            "8.8.8.8;8.8.4.4;77.88.8.8;77.88.8.1", output)
        self.assertSubstringIn("name=failoverPingTries value=5", output)
        self.assertSubstringIn("name=failoverMinPingReplies value=2", output)
        self.assertSubstringIn("name=failoverMaxFailedHosts value=2", output)
        self.assertSubstringIn("name=failoverRecoverCount value=30", output)
        self.assertIn("Settings have been loaded successfully", output)

        # Should use specified values for explicitly specified parameters
        self.upload_settings(no_default_settings=True, custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1",
            "failoverWan2PingSrcAddress": "172.19.10.2",
            "failoverSwitchRoutes": "true",
            "failoverPreferWan2": "true",
            "failoverWan1DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark]",
            "failoverWan2DefaultRoute": "[/ip route find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark]",
            "failoverWan1PingTimeout": "(:totime 00:00:00.055)",
            "failoverWan2PingTimeout": "(:totime 00:00:00.075)",
            "failoverPingTargets": "{\\\"1.1.1.1\\\"; \\\"8.8.4.4\\\"}",
            "failoverPingTries": "6",
            "failoverMinPingReplies": "3",
            "failoverMaxFailedHosts": "1",
            "failoverRecoverCount": "5"
        })
        output = self.run_failover_script()
        self.assertSubstringIn("name=failoverWan1PingTimeout value=00:00:00.055", output)
        self.assertSubstringIn("name=failoverWan2PingTimeout value=00:00:00.075", output)
        self.assertSubstringIn("name=failoverSwitchRoutes value=true", output)
        self.assertSubstringIn("name=failoverPreferWan2 value=true", output)
        self.assertSubstringIn("name=failoverPingTargets value=1.1.1.1;8.8.4.4", output)
        self.assertSubstringIn("name=failoverPingTries value=6", output)
        self.assertSubstringIn("name=failoverMinPingReplies value=3", output)
        self.assertSubstringIn("name=failoverMaxFailedHosts value=1", output)
        self.assertSubstringIn("name=failoverRecoverCount value=5", output)
        self.assertIn("Settings have been loaded successfully", output)

    def test_up_down_detection(self):
        # Should detect wan1 recovery after 3 successful pings
        # 1. Initial state, successful ping
        self.upload_settings(custom_settings={"failoverRecoverCount": "3"})
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 2. wan1 goes down
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 3. successful ping 1
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 4. successful ping 2
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 5. successful ping 3, recovery
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 6. normal operation
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)

        # Should detect wan2 recovery after 3 successful pings
        # 1. Initial state, successful ping
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 2. wan1 goes down
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went down", output)
        # 3. successful ping 1
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 4. successful ping 2
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 5. successful ping 3, recovery
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went up", output)
        # 6. normal operation
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)

    # def test_dummy(self):
        # Should detect both routes recovery after 3 successful pings and some
        # up/downs in between
        # 1. Initial state, successful ping
        # self.upload_settings(custom_settings={"failoverRecoverCount": "3"})
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        # 2. wan1 and wan2 go down
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went down", output)
        # 3. successful ping #1 on wan1, wan2 is still down
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 4. wan1 goes down (counter resets), wan2 is still down
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 5. successful ping #1 on wan1 and #1 on wan2
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=no")
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 6. successful ping #2 on wan1 and #2 on wan2
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=no")
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 7. successful ping #3 on wan1 (recovery), wan2 goes down (counter resets)
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 8. successful ping (uncounted) on wan1, successful ping #1 on wan2
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=no")
        time.sleep(5)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 9. successful ping (uncounted) on wan1, successful ping #2 on wan2
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 10. successful ping (uncounted) on wan1, successful ping #3 on wan2 (recovery)
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went up", output)
        # 11. successful pings (uncounted) on wan1 and wan2
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
