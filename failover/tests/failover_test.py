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
            self.temp_settings_file, "router:failover/write_failover_settings.rsc"))

        subprocess.check_call(("vagrant", "ssh", "router", "--", "/import",
            "failover/write_failover_settings.rsc"),
            cwd=vagrant_path
        )

    def upload_helper_functions(self):
        print("Creating 'failover' directory")
        # There is no direct way to create a directory. This is an ugly hack
        # https://forum.mikrotik.com/viewtopic.php?t=139071
        subprocess.check_call(("vagrant", "ssh", "router", "--",
            '/tool fetch dst-path="/failover/dummy" url="http://127.0.0.1:80/" keep-result=no'),
            cwd=vagrant_path
        )


        functions_definition = (
            ":global TestEnableInterface do={",
            "  /interface ethernet set [find name=$ifName] disabled=no;",
            "  /ip firewall connection remove [/ip firewall connection find protocol=icmp and src-address~(\"^$pingSrcAddr\")]",
            "",
            "  :local pingCounter 0",
            "  :local continuePing true",
            "  while ($continuePing) do={",
            "    :delay 500ms",
            "    if ([/ping count=1 8.8.8.8 src-address=$pingSrcAddr interval=00:00:00.500] = 1) do={ :set continuePing false }",
            "    :set pingCounter ($pingCounter + 1)",
            "    if ($pingCounter > 10) do={",
            "      :put \"Timeout waiting for ping\"",
            "      :set continuePing false",
            "    }",
            "  }",
            "}",

            "if ([:len [/system script find name=failover_on_up_down]] != 0) do={ /system script remove failover_on_up_down }",
            "/system script add name=failover_on_up_down source=\":global failoverWan1IsUp\\r\\",
                "\\n:global failoverWan2IsUp\\r\\",
                "\\n:put (\\\"test_up_down: failoverWan1IsUp=\\$failoverWan1IsUp; failoverWan2IsUp=\\$failoverWan2IsUp\\\")\\r\\",
                "\\n:put (\\\"test_up_down: wan1_distance=\\\" . [/ip route get [find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark] distance])\\r\\",
                "\\n:put (\\\"test_up_down: wan2_distance=\\\" . [/ip route get [find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark] distance])\""
        )
        with open(self.temp_settings_file, "w") as f:
            for line in functions_definition:
                f.write("{}\n".format(line))
        subprocess.check_call(("scp", "-F", self.vagrant_ssh_config,
            self.temp_settings_file, "router:failover/test_functions_definition.rsc"))
        subprocess.check_call(("vagrant", "ssh", "router", "--", "/import",
            "failover/test_functions_definition.rsc"),
            cwd=vagrant_path
        )

        subprocess.check_call(("scp", "-F", self.vagrant_ssh_config,
            os.path.realpath(script_path + "../../version.txt"),
            "router:failover/")
        )


    def run_failover_script(self):
        output = subprocess.check_output(("vagrant", "ssh", "router", "--",
            "/import", "failover/failover_check.rsc"),
            cwd=vagrant_path
        )
        for line in output.decode("utf-8").splitlines():
            print(line)
        return output.decode("utf-8").splitlines()

    def setup_class(cls):
        # cls.longMessage = False
        vm_is_running = False
        output = subprocess.check_output("vagrant status router --machine-readable", shell=True, cwd=vagrant_path)
        for line in output.decode("utf-8").splitlines():
            status_values = line.split(",")
            if (status_values[1] == "router") and (status_values[3] == "running"):
                vm_is_running = True
        if not vm_is_running:
            raise Exception("VM 'router' is not runnig. Bring it up using "
                "'vagrant up' command in {}".format(vagrant_path))

        fd, cls.vagrant_ssh_config = tempfile.mkstemp()
        os.close(fd)
        subprocess.check_call("vagrant ssh-config router > {}".format(cls.vagrant_ssh_config),
            shell=True, cwd=vagrant_path)

        fd, cls.temp_settings_file = tempfile.mkstemp()
        os.close(fd)

        cls.upload_helper_functions(cls)

        failover_script_path = os.path.realpath(script_path + "../../failover_check.rsc")
        subprocess.check_call(("scp", "-F", cls.vagrant_ssh_config,
            failover_script_path, "router:failover/"))


    def teardown_class(self):
        os.remove(self.temp_settings_file)
        os.remove(self.vagrant_ssh_config)

    def assertSubstringIn(self, first, second):
        if not any(first in array_item for array_item in second):
            raise AssertionError("'{}' not found in script output".format(first))

    def assertSubstringNotIn(self, first, second):
        if any(first in array_item for array_item in second):
            raise AssertionError("'{}' unexpectedly found in script output".format(first))

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

        # Should display an error message if settings script contains an error
        self.upload_settings(custom_settings={
            "failoverWan1PingSrcAddress": "172.19.10.1 error",
            "failoverWan2PingSrcAddress": "172.19.10.2"
        })
        output = self.run_failover_script()
        self.assertNotIn("Settings have been loaded successfully", output)
        self.assertIn("ERROR: Error in 'failover_settings' script. Run '/system "
            "script run failover_settings' in the console to view details", output)


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
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
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
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
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
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
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
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        # 6. successful ping #2 on wan1 and #2 on wan2
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
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
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
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

    def test_route_switching(self):
        self.upload_settings(custom_settings={"failoverSwitchRoutes": "true"})
        # Initial state: wan1 route is active, successful pings, no route switching
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertSubstringNotIn("WARNING: wan1 went", output)
        self.assertSubstringNotIn("WARNING: wan2 went", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)

        # Scenario 1: wan1 route is active, wan1 goes down, wan2 is up, route switches to wan2
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertIn("WARNING: Switching default route to 'wan2'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 2: wan2 route is active, wan1 goes back up, wan2 is up, route switches to wan1
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 10; wan2Distance: 5", output)
        self.assertIn("WARNING: Switching default route to 'wan1'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 3: wan1 route is active, wan1 is up, wan2 goes down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 4: wan1 route is active, wan1 is up, wan2 goes back up, no route switching
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went up", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 5: wan1 route is active, wan1 and wan2 go down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 6: wan1 route is active, wan1 is down, wan2 goes up, route switches to wan2
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertIn("WARNING: wan2 went up", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 5; wan2Distance: 10", output)
        self.assertIn("WARNING: Switching default route to 'wan2'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 7: wan2 route is active, wan1 is down, wan2 goes down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 10; wan2Distance: 5", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 8: wan2 route is active, wan1 and wan2 are down, wan1 goes up, route switches to wan1
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 10; wan2Distance: 5", output)
        self.assertIn("WARNING: Switching default route to 'wan1'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Restore normal operation
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")

    def test_route_switching_prefer_wan2(self):
        self.upload_settings(custom_settings={
            "failoverSwitchRoutes": "true",
            "failoverPreferWan2": "true"
        })
        run_ros_command("/ip route set [find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark] distance=10")
        run_ros_command("/ip route set [find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark] distance=5")
        # Initial state: wan2 route is active, successful pings, no route switching
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertSubstringNotIn("WARNING: wan1 went", output)
        self.assertSubstringNotIn("WARNING: wan2 went", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)

        # Scenario 1: wan2 route is active, wan2 goes down, wan1 is up, route switches to wan1
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan2 went down", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertIn("WARNING: Switching default route to 'wan1'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 2: wan1 route is active, wan2 goes back up, wan1 is up, route switches to wan2
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan2 went up", output)
        self.assertNotIn("WARNING: wan1 went down", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 5; wan2Distance: 10", output)
        self.assertIn("WARNING: Switching default route to 'wan2'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 3: wan2 route is active, wan2 is up, wan1 goes down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 4: wan2 route is active, wan2 is up, wan1 goes back up, no route switching
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertNotIn("WARNING: wan2 went down", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 5: wan2 route is active, wan1 and wan2 go down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        run_ros_command("/interface ethernet set [find name=\"wan2\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertIn("WARNING: wan2 went down", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Scenario 6: wan2 route is active, wan2 is down, wan1 goes up, route switches to wan1
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        self.assertIn("WARNING: wan1 went up", output)
        self.assertIn("mainRouteIsActive: true; wan1Distance: 10; wan2Distance: 5", output)
        self.assertIn("WARNING: Switching default route to 'wan1'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=true; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 7: wan1 route is active, wan2 is down, wan1 goes down, no route switching
        run_ros_command("/interface ethernet set [find name=\"wan1\"] disabled=yes")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 1/1/1", output)
        self.assertNotIn("WARNING: wan2 went up", output)
        self.assertIn("WARNING: wan1 went down", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 5; wan2Distance: 10", output)
        self.assertSubstringNotIn("WARNING: Switching default route to", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=false", output)
        self.assertIn("test_up_down: wan1_distance=5", output)
        self.assertIn("test_up_down: wan2_distance=10", output)

        # Scenario 8: wan1 route is active, wan1 and wan2 are down, wan2 goes up, route switches to wan2
        run_ros_command("'$TestEnableInterface ifName=\"wan2\" pingSrcAddr=\"172.19.10.2\"'")
        output = self.run_failover_script()
        self.assertIn("wan1 test results [failed/threshold/total]: 1/1/1", output)
        self.assertIn("wan2 test results [failed/threshold/total]: 0/1/1", output)
        self.assertIn("WARNING: wan2 went up", output)
        self.assertNotIn("WARNING: wan1 went up", output)
        self.assertIn("mainRouteIsActive: false; wan1Distance: 5; wan2Distance: 10", output)
        self.assertIn("WARNING: Switching default route to 'wan2'", output)
        self.assertIn("test_up_down: failoverWan1IsUp=false; failoverWan2IsUp=true", output)
        self.assertIn("test_up_down: wan1_distance=10", output)
        self.assertIn("test_up_down: wan2_distance=5", output)

        # Restore normal operation
        run_ros_command("'$TestEnableInterface ifName=\"wan1\" pingSrcAddr=\"172.19.10.1\"'")
        # Restore default route distances
        run_ros_command("/ip route set [find dst-address=0.0.0.0/0 and gateway=192.168.120.10 and !routing-mark] distance=5")
        run_ros_command("/ip route set [find dst-address=0.0.0.0/0 and gateway=192.168.121.10 and !routing-mark] distance=10")

    def test_script_version(self):
        # It should display current script version
        run_ros_command(" /file set failover/version.txt contents=\"script_ver\"")
        output = self.run_failover_script()
        self.assertIn("Version script_ver", output)

        # It should display only first line of the version file
        run_ros_command("'/file set failover/version.txt contents=\"ver_line1\\n\\rver_line2\"'")
        output = self.run_failover_script()
        self.assertIn("Version ver_line1", output)
        self.assertSubstringNotIn("rver_line2", output)

        # It should display UNKNOWN if version file is missing
        run_ros_command("/file remove failover/version.txt")
        output = self.run_failover_script()
        self.assertIn("Version UNKNOWN", output)

        # Restore current version file
        subprocess.check_call(("scp", "-F", self.vagrant_ssh_config,
            os.path.realpath(script_path + "../../version.txt"),
            "router:failover/")
        )
