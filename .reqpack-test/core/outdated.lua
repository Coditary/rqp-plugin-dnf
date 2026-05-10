return {
  name = "dnf outdated",
  request = {
    action = "outdated",
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
      match = "dnf repoquery --upgrades --queryformat '%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n'",
      exitCode = 0,
      stdout = "curl|8.9.1-1.fc40|x86_64|updates|Command line tool for transferring data\n",
      stderr = "",
      success = true,
    },
    {
      match = "rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' 'curl'",
      exitCode = 0,
      stdout = "8.8.0-1.fc40\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 1,
    resultName = "curl",
    resultVersion = "8.8.0-1.fc40",
  }
}
