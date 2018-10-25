# Psake Guidelines

## Reserved Task Names

| Task                      | Script                        |
|---------------------------|-------------------------------|
| init-winrm                | Saritasa.AdminTasks.ps1       |
| import-sites              | Saritasa.AdminTasks.ps1       |
| export-sites              | Saritasa.AdminTasks.ps1       |
| trust-host                | Saritasa.AdminTasks.ps1       |
| gitflow-hotfixes-releases | Saritasa.GitTasks.ps1         |
| gitflow-old-features      | Saritasa.GitTasks.ps1         |
| gitflow-features          | Saritasa.GitTasks.ps1         |
| gitflow-status            | Saritasa.GitTasks.ps1         |
| help                      | Saritasa.PsakeTasks1.ps1      |
| default                   | Saritasa.PsakeTasks1.ps1      |
| update-gallery            | Saritasa.PsakeTasks1.ps1      |
| add-scripts-to-git        | Saritasa.PsakeTasks1.ps1      |
| setup-jenkins             | Saritasa.BuildServerTasks.ps1 |
| setup-workspace           | Saritasa.BuildServerTasks.ps1 |
| import-jenkins            | Saritasa.BuildServerTasks.ps1 |
| export-jenkins            | Saritasa.BuildServerTasks.ps1 |
| write-ssh-key             | Saritasa.BuildServerTasks.ps1 |
| write-jenkins-password    | Saritasa.BuildServerTasks.ps1 |

## Recommended Task Names

| Task                | Description    |
|---------------------|----------------|
| build               |                |
| build-docs          |                |
| clean               |                |
| clean-all           |                |
| copy-artifacts      |                |
| copy-configs        |                |
| import-certificate  |                |
| nuget-restore       |                |
| package-web         |                |
| pre-build           |                |
| pre-publish         |                |
| publish-api         |                |
| publish-service     |                |
| publish-web         |                |
| serve-docs          |                |
| setup-build-server  |                |
| setup-build-soft    |                |
| setup-web-server    |                |
| setup-web-soft      |                |
| sync-web            |                |
| update-version      |                |

## Reserved Property Names

| Property             | Description    |
|----------------------|----------------|
| AdminUsername        |                |
| AdminPassword        |                |
| ApprootPath          |                |
| AssemblySemVer       |                |
| ConfigInitialized    |                |
| Configuration        |                |
| Environment          |                |
| DeployUsername       |                |
| DeployPassword       |                |
| InformationalVersion |                |
| MajorMinorPatch      |                |
| ServerHost           |                |
| SiteName             |                |
| WwwrootPath          |                |
| WinrmAuthentication  |                |
| WinrmPort            |                |
| WorkspacePath        |                |

## Recommended Property Names

| Property             | Description    |
|----------------------|----------------|
| AppServer            |                |
| DistrPath            |                |
| WebServer            |                |
