# Getting Started

## Scaffolding

Use [Yeoman](http://yeoman.io/) to quickly generate script templates and start editing them.

* Install [Chocolatey](https://chocolatey.org/).
* Install Node.js.

        cinst nodejs -y

* Install Yeoman and generator.

        npm install -g yo generator-psgallery

* Run the generator in project root directory.

        yo psgallery

* Follow the wizard steps.

Note: You may use VS Code Yeoman extension.

### Update Generator

    npm update -g generator-psgallery

## Add Module

- Open repository root directory in PowerShell.
- Execute command (`Saritasa.Git` is example):
    ```
    Save-Module Saritasa.Git -Path .\scripts\modules\
    ```
- Execute command:
    ```
    psake add-scripts-to-git
    ```
- Make Git commit.

## Add Script

- Open repository root directory in PowerShell.
- Execute command (replace URL):
    ```
    iwr https://raw.githubusercontent.com/Saritasa/PSGallery/master/scripts/Psake/Saritasa.GitTasks.ps1 -OutFile .\scripts\Saritasa.GitTasks.ps1
    ```
- Add a line to `psakefile.ps1`:
    ```
    . .\scripts\Saritasa.GitTasks.ps1
    ```
- Execute command:
    ```
    psake add-scripts-to-git
    ```
- Make Git commit.
