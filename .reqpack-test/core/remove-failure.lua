return {
  name = "dnf remove failure",
  request = {
    action = "remove",
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
      match = "dnf remove -y 'missing-curl'",
      exitCode = 1,
      stdout = "",
      stderr = "No match for argument: missing-curl\n",
      success = false,
    }
  },
  expect = {
    success = false,
    commands = { "dnf remove -y 'missing-curl'" },
    stderr = { "No match for argument: missing-curl\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dnf remove failed",
    },
  }
}
