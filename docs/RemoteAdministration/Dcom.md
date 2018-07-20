DCOM
====

Many legacy management tools are powered by DCOM. The Microsoft DCOM uses MSRPC which is based on DCE/RPC.

RPC uses TCP ports 135 and 445 (SMB for named pipes). It may use other ports also. See the article: [Service overview and network port requirements for Windows](https://support.microsoft.com/en-us/help/832017/service-overview-and-network-port-requirements-for-windows#method38)

Start Computer Management in Domain
-----------------------------------

You may start Computer Management from Server Manager.

![](./images/ServerManager01.png)

![](images/ComputerManagement02.png)

Start Computer Management in Workgroup
--------------------------------------

Our workgroup PC does not know about Active Directory DNS. We'll add a hostname to the hosts file.

```powershell
Add-Content -Encoding UTF8 "$($env:windir)\system32\Drivers\etc\hosts" '192.168.11.137 server2019.saritasa.local'
```

We can't connect to domain servers from a workgroup PC directly. DCOM uses network level authentication. Process needs to have a correct user identity. We'll use the `runas` tool, it requires administrator permissions.

```powershell
runas /user:anton@saritasa.local /netonly "mmc compmgmt.msc /computer:server2019.saritasa.local"
```

```powershell
PS C:\Users\anton> Add-Content -Encoding UTF8 "$($env:windir)\system32\Drivers\etc\hosts" '192.168.11.137 server2019.saritasa.local'
PS C:\Users\anton> runas /user:anton@saritasa.local /netonly "mmc compmgmt.msc /computer:server2019.saritasa.local"
Enter the password for anton@saritasa.local:
Attempting to start mmc compmgmt.msc /computer:server2019.saritasa.local as user "anton@saritasa.local" ...
```

![](images/ComputerManagement03.png)

We connected to a domain server. We also can connect to a workgroup server with different administrator credentials.

```powershell
runas /user:administrator /netonly "mmc compmgmt.msc /computer:hyper1"
```

![](images/ComputerManagement04.png)

Start MMC in Domain
-------------------

Start MMC, add a snap-in and connect to another server in domain.

![](images/Mmc01.png)

![](images/Mmc02.png)

![](images/Mmc03.png)

![](images/Mmc04.png)

You may also run a snap-in from command line:

```powershell
compmgmt.msc /computer:server2019.saritasa.local
```

![](images/Mmc05.png)

You may save MMC console to file to quickly open necessary snap-ins later.

![](images/Mmc06.png)

Firewall Configuration
----------------------

An error is shown if firewall rules are not configured.

![](images/ComputerManagement01.png)

Connect to the target server by WinRM. Execute following command to enable firewall rules for computer management:

```powershell
Set-NetFirewallRule -DisplayGroup 'Remote Event Log Management' -Enabled True -PassThru | select DisplayName
```

Example:

```powershell
[server2019.saritasa.local]: PS C:\Users\anton\Documents> Set-NetFirewallRule -DisplayGroup 'Remote Event Log Management' -Enabled True -PassThru | select DisplayName

DisplayName
-----------
Remote Event Log Management (RPC)
Remote Event Log Management (RPC-EPMAP)
Remote Event Log Management (NP-In)
```

The `Remote Event Log Management` group controls access to following services:

- Event Viewer
- Shared Folders
- Local Users and Groups
- Performance Monitor
- Services

