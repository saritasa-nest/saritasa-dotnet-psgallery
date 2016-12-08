# WinRM Configuration

## Windows Server 2008, 2008 R2, 2012, 2012 R2

1. Run as administrator:

        # Install Chocolatey.
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        # Update WMF and PowerShell to version 5.
        cinst powershell -y
        # Restart server to apply PowerShell updates.
        Restart-Computer

2. Run as administrator after restart:

        # Install a module to local repository. Hit <Enter> to approve NuGet installation.
        Install-Module Saritasa.WinRM -Force
        # Run script to configure WinRM.
        Install-WinrmHttps
