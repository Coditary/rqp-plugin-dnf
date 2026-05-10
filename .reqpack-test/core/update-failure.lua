return {
  name = "dnf update failure",
  request = {
    action = "update",
    system = "dnf",
    packages = {
      { name = "missing-curl" }
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
      match = "dnf upgrade -y 'missing-curl'",
      exitCode = 1,
      stdout = "",
      stderr = "No match for argument: missing-curl\n",
      success = false,
    }
  },
  expect = {
    success = false,
    commands = { "dnf upgrade -y 'missing-curl'" },
    stderr = { "No match for argument: missing-curl\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dnf upgrade failed",
    },
  }
}
