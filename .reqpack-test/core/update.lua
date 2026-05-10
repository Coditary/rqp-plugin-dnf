return {
  name = "dnf update",
  request = {
    action = "update",
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
      match = "dnf upgrade -y 'curl'",
      exitCode = 0,
      stdout = "Upgraded:\n  curl\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
