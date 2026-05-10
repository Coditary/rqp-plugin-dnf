return {
  name = "dnf install",
  request = {
    action = "install",
    system = "dnf",
    packages = {
      { name = "curl", version = "8.9.1" }
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
      match = "dnf install -y 'curl-8.9.1'",
      exitCode = 0,
      stdout = "Installed:\n  curl-8.9.1\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      success = "ok",
    },
  }
}
