# Scripts

## Psake

| Name                                                             | Description                                                                                                                                     |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Saritasa.AdminTasks.ps1                                          | Contains Psake tasks for remote server administration. |
| Saritasa.GitTasks.ps1                                            | Contains Psake tasks for Git repository maintenance. |
| [Saritasa.PsakeExtensions.ps1](docs/Saritasa.PsakeExtensions.md) | The script is intended for dot-sourcing into default.ps1 (main file for Psake tasks). It allows to override Psake properties from another file. |
| Saritasa.PsakeTasks.ps1                                          | Contains common Psake tasks. |

## WebDeploy

Microsoft scripts to set up msdeploy for web site. They are modified to skip SKU check for modern Windows versions.

| Name                      | Description     |
| ------------------------- | --------------- |
| AddDelegationRules.ps1    |                 |
| SetupSiteForPublish.ps1   |                 |
