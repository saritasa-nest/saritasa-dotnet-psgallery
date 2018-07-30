SSH
===

OpenSSH is a built-in component of Windows Server 2016 and Windows 10.

Use following commands to install OpenSSH server:

```powershell
PS C:\Users\anton> Get-WindowsCapability -Online | ? Name -like 'OpenSSH*'


Name  : OpenSSH.Client~~~~0.0.1.0
State : NotPresent

Name  : OpenSSH.Server~~~~0.0.1.0
State : NotPresent
```

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Use administrator credentials for connection.

Read [the article](https://blogs.msdn.microsoft.com/powershell/2017/12/15/using-the-openssh-beta-in-windows-10-fall-creators-update-and-windows-server-1709/) for advanced configuration.
