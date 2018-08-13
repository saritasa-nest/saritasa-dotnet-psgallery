var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');
var fs = require('fs');

const WEB = 'Web';
const DESKTOP = 'Desktop';
const CLICK_ONCE = 'ClickOnce';
const WINDOWS_SERVICE = 'Windows Service';

const NEWRELIC = 'NewRelic';
const PRTG = 'PRTG';
const REDIS = 'Redis';

module.exports = generators.Base.extend({
    constructor: function () {
        generators.Base.apply(this, arguments);

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
    },
    initializing: function () {
        this.modulesPath = this.destinationPath('scripts/modules');
        this.adminTasksEnabled = false;
    },
    prompting: function () {
        let askingQuestions = [{
            type: 'checkbox',
            name: 'projectTypes',
            message: 'Select all used project types:',
            choices: [WEB, DESKTOP, CLICK_ONCE, WINDOWS_SERVICE]
        }, {
            type: 'confirm',
            name: 'gitTasksEnabled',
            message: 'Do you need GitFlow helper tasks?',
            default: true
        }, {
            type: 'confirm',
            name: 'nunitEnabled',
            message: 'Do you need to run NUnit tests?',
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
            this.gitTasksEnabled = answers.gitTasksEnabled;
            this.nunitEnabled = answers.nunitEnabled;

            if (this.projectTypes.indexOf(WEB) > -1) {
                return this.prompt([{
                    type: 'confirm',
                    name: 'adminTasksEnabled',
                    message: 'Do you need admin tasks, remote management capabilities?',
                    default: true
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
    },
    writing: function () {
        mkdirp.sync(this.modulesPath);

        this.projectTypes = this.projectTypes || [];
        this.webServices = this.webServices || [];

        var webEnabled = this.projectTypes.indexOf(WEB) > -1;
        var desktopEnabled = this.projectTypes.indexOf(DESKTOP) > -1;
        var clickOnceEnabled = this.projectTypes.indexOf(CLICK_ONCE) > -1;
        var windowsServiceEnabled = this.projectTypes.indexOf(WINDOWS_SERVICE) > -1;

        var templateParams = {
            srcPath: this.srcPath,
            adminTasksEnabled: this.adminTasksEnabled,
            desktopEnabled: desktopEnabled,
            webEnabled: webEnabled,
            windowsServiceEnabled: windowsServiceEnabled,
            gitTasksEnabled: this.gitTasksEnabled
        };

        this.fs.copyTpl(this.templatePath('psakefile.ps1'),
            this.destinationPath('psakefile.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('Config.Development.ps1.template'),
            this.destinationPath('Config.Development.ps1.template'), templateParams);
        this.fs.copyTpl(this.templatePath('Config.Production.ps1'),
            this.destinationPath('Config.Production.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('SecretConfig.Production.ps1.template'),
            this.destinationPath('SecretConfig.Production.ps1.template'), templateParams);

        this.fs.copyTpl(this.templatePath('scripts/BuildTasks.ps1'), this.destinationPath('scripts/BuildTasks.ps1'), templateParams);
        this.fs.copyTpl(this.templatePath('scripts/PublishTasks.ps1'), this.destinationPath('scripts/PublishTasks.ps1'), templateParams);
        this.fs.copy(this.templatePath('scripts/Saritasa.PsakeExtensions.ps1'), this.destinationPath('scripts/Saritasa.PsakeExtensions.ps1'));
        this.fs.copy(this.templatePath('scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('scripts/Saritasa.PsakeTasks.ps1'));

        this.installModule('Saritasa.Build');

        if (webEnabled) {
            this.installModule('Saritasa.WebDeploy');
        }

        if (clickOnceEnabled) {
            this.installModule('Saritasa.Publish');
        }

        if (desktopEnabled || windowsServiceEnabled) {
            this.installModule('Saritasa.AppDeploy');
        }

        if (this.nunitEnabled) {
            this.installModule('Saritasa.Test');
        }

        if (this.adminTasksEnabled) {
            this.fs.copy(this.templatePath('Scripts/Saritasa.AdminTasks.ps1'), this.destinationPath('Scripts/Saritasa.AdminTasks.ps1'));
            this.installModule('Saritasa.RemoteManagement');
        }

        if (this.gitTasksEnabled) {
            this.fs.copy(this.templatePath('Scripts/Saritasa.GitTasks.ps1'), this.destinationPath('Scripts/Saritasa.GitTasks.ps1'));
            this.installModule('Saritasa.Git');
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

        this.log('Please ignore following file:\nConfig.Development.ps1');
    }
});
