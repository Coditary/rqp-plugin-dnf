return {
  name = "dnf list installed",
  request = {
    action = "list",
    system = "dnf",
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
      match = "rpm -qa --queryformat '%{NAME}|%{VERSION}-%{RELEASE}|%{ARCH}|%{LICENSE}|%{SUMMARY}\\n'",
      exitCode = 0,
      stdout = "curl|8.9.1-1.fc40|x86_64|curl|Command line tool for transferring data\ngit|2.45.1-1.fc40|x86_64|GPL-2.0-only|Fast distributed version control system\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "curl",
    resultVersion = "8.9.1-1.fc40",
  }
}
