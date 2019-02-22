var Generator = require('yeoman-generator');
var mkdirp = require('mkdirp');
var fs = require('fs');
var chalk = require('chalk');

const WEB = 'Web';
const DESKTOP = 'Desktop';
const CLICK_ONCE = 'ClickOnce';
const WINDOWS_SERVICE = 'Windows Service';

const NEWRELIC = 'NewRelic';
const PRTG = 'PRTG';
const REDIS = 'Redis';

module.exports = class extends Generator {
    constructor(args, opts) {
        super(args, opts);

        this.installModule = function (name) {
            fs.access(this.modulesPath + '\\' + name, function (err) {
                if (err) {
                    this.log('Installing ' + name + ' module...');
                    this.spawnCommandSync('powershell', ['-Command', '&{ Save-Module ' + name + ' -Path ' + this.modulesPath + ' }']);
                    this.log('OK');
                } else {
                    this.log('Module ' + name + ' is installed already.');
                }
            }.bind(this));
        };
    }

    initializing() {
        this.modulesPath = this.destinationPath('scripts/modules');
        this.adminTasksEnabled = false;
    }

    prompting() {
        let askingQuestions = [{
            type: 'checkbox',
            name: 'projectTypes',
            message: 'Select all used project types:',
            choices: [WEB, DESKTOP, CLICK_ONCE, WINDOWS_SERVICE]
        }, {
            type: 'confirm',
            name: 'vaultEnabled',
            message: 'Is Vault used?',
            default: true
        }, {
            type: 'confirm',
            name: 'netCoreUsed',
            message: 'Is .NET Core used?',
            default: true
        }, {
            type: 'confirm',
            name: 'gitTasksEnabled',
            message: 'Do you need GitFlow helper tasks?',
            default: true
        }, {
            type: 'confirm',
            name: 'nunitEnabled',
            message: 'Do you need to run NUnit or xUnit tests?',
            default: false
        }];
        let predefinedSrcPath = this.options && this.options.srcPath;
        if (!predefinedSrcPath) {
            askingQuestions.unshift({
                type: 'input',
                name: 'srcPath',
                message: 'Where are project source files located (relative to BuildTasks.ps1)?',
                default: '..\\src'
            });
        }
        return this.prompt(askingQuestions).then(function (answers) {
            this.projectTypes = answers.projectTypes;
            this.srcPath = predefinedSrcPath || answers.srcPath;
            this.vaultEnabled = answers.vaultEnabled;
            this.netCoreUsed = answers.netCoreUsed;
            this.gitTasksEnabled = answers.gitTasksEnabled;
            this.nunitEnabled = answers.nunitEnabled;

            if (this.projectTypes.indexOf(WEB) > -1) {
                return this.prompt([{
                    type: 'confirm',
                    name: 'adminTasksEnabled',
                    message: 'Do you need admin tasks, remote management capabilities?',
                    default: false
                }, {
                    type: 'checkbox',
                    name: 'webServices',
                    message: 'Select services which you want to control from PowerShell:',
                    choices: [NEWRELIC, PRTG, REDIS]
                }]);
            }
        }.bind(this)).then(function (answers) {
            if (answers !== undefined) {
                this.adminTasksEnabled = answers.adminTasksEnabled;
                this.webServices = answers.webServices;
            }
        }.bind(this));
    }

    writing() {
        mkdirp.sync(this.modulesPath);

        this.projectTypes = this.projectTypes || [];
        this.webServices = this.webServices || [];

        this.webEnabled = this.projectTypes.indexOf(WEB) > -1;
        this.desktopEnabled = this.projectTypes.indexOf(DESKTOP) > -1;
        this.clickOnceEnabled = this.projectTypes.indexOf(CLICK_ONCE) > -1;
        this.windowsServiceEnabled = this.projectTypes.indexOf(WINDOWS_SERVICE) > -1;

        var templateParams = {
            srcPath: this.srcPath,
            adminTasksEnabled: this.adminTasksEnabled,
            desktopEnabled: this.desktopEnabled,
            webEnabled: this.webEnabled,
            vaultEnabled: this.vaultEnabled,
            netCoreUsed: this.netCoreUsed,
            windowsServiceEnabled: this.windowsServiceEnabled,
            gitTasksEnabled: this.gitTasksEnabled,
            testsUsed: this.nunitEnabled
        };

        this.fs.copyTpl(this.templatePath('psakefile.ps1'),
            this.destinationPath('psakefile.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('Config.Development.ps1'),
            this.destinationPath('Config.Development.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('Config.Staging.ps1'),
            this.destinationPath('Config.Staging.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('Config.Production.ps1'),
            this.destinationPath('Config.Production.ps1'), templateParams);

        this.fs.copyTpl(this.templatePath('scripts/BuildTasks.ps1'), this.destinationPath('scripts/BuildTasks.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('scripts/PublishTasks.ps1'), this.destinationPath('scripts/PublishTasks.ps1'), templateParams);
        this.fs.copy(this.templatePath('scripts/Saritasa.PsakeExtensions.ps1'), this.destinationPath('scripts/Saritasa.PsakeExtensions.ps1'));
        this.fs.copy(this.templatePath('scripts/Saritasa.BuildTasks.ps1'), this.destinationPath('scripts/Saritasa.BuildTasks.ps1'));
        this.fs.copy(this.templatePath('scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('scripts/Saritasa.PsakeTasks.ps1'));

        this.installModule('Saritasa.Build');

        if (this.webEnabled) {
            this.installModule('Saritasa.WebDeploy');
        }

        if (this.clickOnceEnabled) {
            this.installModule('Saritasa.Publish');
        }

        if (this.desktopEnabled || this.windowsServiceEnabled) {
            this.installModule('Saritasa.AppDeploy');
        }

        if (this.nunitEnabled) {
            this.installModule('Saritasa.Test');
        }

        if (this.adminTasksEnabled || this.desktopEnabled || this.windowsServiceEnabled) {
            this.fs.copy(this.templatePath('Scripts/Saritasa.AdminTasks.ps1'), this.destinationPath('Scripts/Saritasa.AdminTasks.ps1'));
            this.installModule('Saritasa.RemoteManagement');
        }

        if (this.gitTasksEnabled) {
            this.fs.copy(this.templatePath('Scripts/Saritasa.GitTasks.ps1'), this.destinationPath('Scripts/Saritasa.GitTasks.ps1'));
            this.installModule('Saritasa.Git');
        }

        if (this.vaultEnabled) {
            this.installModule('PowerVault');
        }

        if (this.webServices.indexOf(NEWRELIC) > -1) {
            this.installModule('Saritasa.NewRelic');
        }

        if (this.webServices.indexOf(PRTG) > -1) {
            this.installModule('Saritasa.Prtg');
        }

        if (this.webServices.indexOf(REDIS) > -1) {
            this.installModule('Saritasa.Redis');
        }
    }

    end() {
        this.log('\n\n');
        this.log(chalk.black.bgGreen('Please execute commands:'));
        var ignoreList = 'Config.ps1';

        if (this.webEnabled) {
            if (this.netCoreUsed) {
                ignoreList += '`r`nweb.config';
            }
            else {
                ignoreList += '`r`nWeb.config';
                ignoreList += '`r`nWeb.Development.config';
            }
        }

        if (this.netCoreUsed) {
            ignoreList += '`r`nappsettings.Development.json';
        }
        else if (this.desktopEnabled || this.windowsServiceEnabled) {
            ignoreList += '`r`nApp.config';
            ignoreList += '`r`nApp.Development.config';
        }

        this.log(chalk.green(`Add-Content -Path .gitignore "${ignoreList}"`));
        this.log(chalk.green('psake add-scripts-to-git'));
        this.log('\n\n');
    }
};
