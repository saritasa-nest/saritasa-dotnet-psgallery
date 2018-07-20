DCOM
====

Many legacy management tools are powered by DCOM. The Microsoft DCOM uses MSRPC which is based on DCE/RPC.

RPC uses TCP ports 135 and 445 (SMB for named pipes). It may use other ports also. See the article: [Service overview and network port requirements for Windows](https://support.microsoft.com/en-us/help/832017/service-overview-and-network-port-requirements-for-windows#method38)

Start Computer Management in Domain
-----------------------------------

You may start Computer Management from Server Manager.

![](./images/ServerManager01.png)

![](images/ComputerManagement02.png)

Start MMC in Domain
-------------------

Start MMC, add a snap-in and connect to another server in domain.

![](images/Mmc01.png)

![](images/Mmc02.png)

![](images/Mmc03.png)

![](images/Mmc04.png)

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

