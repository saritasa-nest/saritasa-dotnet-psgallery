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


```powershell
PS C:\Users\anton> ssh administrator@server2019.saritasa.local
The authenticity of host 'server2019.saritasa.local (192.168.11.137)' can't be established.
ECDSA key fingerprint is SHA256:LjsYblKkKkaidWJBpSuL+PivLoMU0CBD9Nv0lIqznwU.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'server2019.saritasa.local' (ECDSA) to the list of known hosts.
administrator@server2019.saritasa.local's password:
```

```powershell
Microsoft Windows [Version 10.0.17666.1000]
(c) 2018 Microsoft Corporation. All rights reserved.

administrator@SERVER2019 C:\Users\Administrator>hostname
server2019
```

Read [the article](https://blogs.msdn.microsoft.com/powershell/2017/12/15/using-the-openssh-beta-in-windows-10-fall-creators-update-and-windows-server-1709/) for advanced configuration.

PowerShell Core SSH Remoting
----------------------------

PowerShell Core supports WSMan and SSH for remoting.

Configure SSH subsystem on server according to [the article](https://docs.microsoft.com/en-us/powershell/scripting/core-powershell/SSH-Remoting-in-PowerShell-Core?view=powershell-6).

Use Chocolatey to install PowerShell Core to client:

```powershell
cinst powershell-core -y
```

Alternatively follow the article: [Installing PowerShell Core on Windows](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-windows?view=powershell-6)

Run PowerShell 6.0.2 from Start menu or by full path: `C:\Program Files\PowerShell\6.0.2\posh.exe`

Connect to server:

```powershell
PS C:\Program Files\PowerShell\6.0.2> Enter-PSSession -HostName server2019.saritasa.local -UserName administrator
```
