return {
  name = "dnf install failure",
  request = {
    action = "install",
    system = "dnf",
    packages = {
      { name = "missing-curl", version = "8.9.1" }
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
      match = "dnf install -y 'missing-curl-8.9.1'",
      exitCode = 1,
      stdout = "",
      stderr = "No match for argument: missing-curl-8.9.1\n",
      success = false,
    }
  },
  expect = {
    success = false,
    commands = { "dnf install -y 'missing-curl-8.9.1'" },
    stderr = { "No match for argument: missing-curl-8.9.1\n" },
    events = { "failed" },
    eventPayloads = {
      failed = "dnf install failed",
    },
  }
}
