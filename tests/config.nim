import unittest
import nico

suite "config":
  setup:
    nico.init("nico","tests")
    nico.createWindow("test",32,32,1)

  teardown:
    nico.shutdown()

  test "config":
    loadConfig()

  test "updateConfigValue":
    updateConfigValue("Test", "entry", "value")
    saveConfig()

  test "getConfigValue":
    loadConfig()
    check(getConfigValue("Test", "entry") == "value")
