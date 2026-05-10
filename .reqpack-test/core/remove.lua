return {
  name = "dnf remove",
  request = {
    action = "remove",
    system = "dnf",
    packages = {
      { name = "curl" }
    },
  },
  fakeExec = {
    {
      match = "command -v 'dnf' >/dev/null 2>&1",
      exitCode = 0,
      stdout = "",
      stderr = "",
      success = true,
    },
    {
      match = "dnf remove -y 'curl'",
      exitCode = 0,
      stdout = "Removed:\n  curl\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
