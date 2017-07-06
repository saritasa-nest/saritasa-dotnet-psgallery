# WinRM Configuration

1. Make sure you have PowerShell 5 installed.

        $PSVersionTable.PSVersion

2. Run as administrator in PowerShell:

        # Install a module to local repository. Hit <Enter> to approve NuGet installation.
        Install-Module Saritasa.WinRM -Force
        # Run script to configure WinRM.
        Install-WinrmHttps

    You may install NuGet package provider in advance.

        Install-PackageProvider NuGet -Force

    One-line command:

        Install-PackageProvider NuGet -Force; Install-Module Saritasa.WinRM -Force; Install-WinrmHttps

## Install PowerShell 5

[Installing Windows PowerShell](https://msdn.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell)

### Windows Server 2016

PowerShell 5 is installed already.

### Windows Server 2012, 2012 R2

Run as administrator in PowerShell:

        # Install Chocolatey.
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        # Update WMF and PowerShell to version 5.
        cinst powershell -y
        # Restart server to apply PowerShell updates.
        Restart-Computer

### Windows Server 2008, 2008 R2

Run as administrator in PowerShell:

        Set-ExecutionPolicy RemoteSigned
        # Install Chocolatey.
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        # Update .NET Framework.
        cinst dotnet4.5.2 -y
        # Update WMF and PowerShell to version 5.
        cinst powershell -y
        # Restart server to apply PowerShell updates.
        Restart-Computer

### Windows Server 2008 R2 Server Core

1. Run following commands:

        dism /online /enable-feature:NetFx2-ServerCore
        dism /online /enable-feature:MicrosoftWindowsPowerShell
        dism /online /enable-feature:NetFx2-ServerCore-WOW64

2. Start PowerShell 2.0: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`

3. Install ServerManager cmdlets:

        Dism.exe /Online /Enable-Feature /FeatureName:ServerManager-PSH-Cmdlets

3. Run in PowerShell:

        # Install .NET 4.5.2.
        $path = "$env:TEMP\NDP452.exe"
        (New-Object System.Net.WebClient).DownloadFile("http://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe", $path)
        Start-Process -NoNewWindow -Wait $path '/Passive'
        # Install Chocolatey.
        Set-ExecutionPolicy RemoteSigned
        $env:chocolateyUserWindowsCompression = 'false'
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        # Update WMF and PowerShell to version 5.
        cinst powershell -y
        # Restart server to apply PowerShell updates.
        Restart-Computer
