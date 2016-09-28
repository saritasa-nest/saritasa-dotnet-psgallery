# PowerShell Gallery

The repository contains useful PowerShell modules and scripts to be reused in different projects.

# Modules

| Name                      | Description                                                                                                                       |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [Saritasa.Build](docs/Saritasa.Build.md)                               | Contains functions to execute MSBuild targets, restore NuGet packages, run EntityFramework migrations. |
| [Saritasa.NewRelic](docs/Saritasa.NewRelic.md)                         | Contains functions to call New Relic (newrelic.com) service APIs. |
| [Saritasa.Prtg](docs/Saritasa.Prtg.md)                                 | Contains functions to call PRTG monitoring service (www.paessler.com/prtg) APIs. |
| [Saritasa.Web](docs/Saritasa.Web.md)                                   | Contains various methods for web requests and SSL handling. |
| [Saritasa.Psake](docs/Saritasa.Psake.md)                               | Contains common Psake tasks. |
| [Saritasa.Publish](docs/Saritasa.Publish.md)                           | Contains methods to generate ClickOnce packages. |
| [Saritasa.RemoteManagement](docs/Saritasa.RemoteManagement.md)         | Contains functions to execute actions on a remote server. Allows to set up IIS, import sites and app pools, install MSI packages. |
| [Saritasa.Test](docs/Saritasa.Test.md)                                 | Contains functions to run unit tests. |
| [Saritasa.Web](docs/Saritasa.Web.md)                                   | Contains various methods for web requests and SSL handling. |
| [Saritasa.WebDeploy](docs/Saritasa.WebDeploy.md)                       | Contains functions to control app pools and synchronize IIS web sites using Microsoft WebDeploy tool. |

# Scripts

## Psake

| Name                                                             | Description                                                                                                                                     |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| [Saritasa.PsakeExtensions.ps1](docs/Saritasa.PsakeExtensions.md) | The script is intended for dot-sourcing into default.ps1 (main file for Psake tasks). It allows to override Psake properties from another file. |

## WebDeploy

Microsoft scripts to set up msdeploy for web site. They are modified to skip SKU check for modern Windows versions.

| Name                      | Description     |
| ------------------------- | --------------- |
| AddDelegationRules.ps1    |                 |
| SetupSiteForPublish.ps1   |                 |

## WinRM

| Name                      | Description                                               |
| ------------------------- | --------------------------------------------------------- |
| Install-WinrmHttps.ps1    | Configures server to accept WinRM connections over HTTPS. |

# Links

## Cmdlet Collections 

* [Carbon](http://get-carbon.org/)

## Code Style

* [Cmdlet Development Guidelines](https://msdn.microsoft.com/en-us/library/ms714657(v=vs.85).aspx)
* [Building a PowerShell Module](http://ramblingcookiemonster.github.io/Building-A-PowerShell-Module/)

## Static Analysis

* [PowerShell Script Analyzer: Static Code analysis for Windows PowerShell scripts & modules](https://blogs.msdn.microsoft.com/powershell/2015/02/24/powershell-script-analyzer-static-code-analysis-for-windows-powershell-scripts-modules/)
* [PSScriptAnalyzer](https://www.powershellgallery.com/packages/PSScriptAnalyzer)

## Documentation Generation

* [psDoc](https://github.com/ChaseFlorell/psDoc)
* [DocTreeGenerator](https://github.com/msorens/DocTreeGenerator)
