return {
  name = "dnf search",
  request = {
    action = "search",
    system = "dnf",
    prompt = "curl",
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
      match = "dnf repoquery --available --latest-limit 1 --queryformat '%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n' '*curl*'",
      exitCode = 0,
      stdout = "curl|8.9.1-1.fc40|x86_64|updates|Command line tool for transferring data\ncurl-minimal|8.9.1-1.fc40|x86_64|updates|Minimal command line tool for transferring data\n",
      stderr = "",
      success = true,
    }
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 2,
    resultName = "curl",
    resultVersion = "8.9.1-1.fc40",
  }
}
