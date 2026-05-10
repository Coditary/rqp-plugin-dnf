return {
  name = "dnf install local rpm",
  request = {
    action = "install",
    system = "dnf",
    localPath = "/tmp/curl.rpm",
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
      match = "dnf install -y '/tmp/curl.rpm'",
      exitCode = 0,
      stdout = "Installed:\n  curl.rpm\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{localTarget=true, path=/tmp/curl.rpm}",
      success = "ok",
    },
  }
}
