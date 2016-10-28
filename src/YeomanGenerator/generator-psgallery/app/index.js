var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');

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
            this.log('Installing ' + name + ' module...');
            this.spawnCommandSync('powershell', ['-Command', '&{ Save-Module ' + name + ' -Path ' + this.modulesPath + ' }']);
            this.log('OK');
        };
    },
    initializing: function () {
        this.modulesPath = this.destinationPath('scripts/modules');
        this.adminTasksEnabled = false;
    },
    prompting: function () {
        return this.prompt({
            type: 'checkbox',
            name: 'projectTypes',
            message: 'Select all used project types:',
            choices: [WEB, DESKTOP, CLICK_ONCE, WINDOWS_SERVICE]
        }).then(function (answers) {
            this.projectTypes = answers.projectTypes;

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

        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));

        this.projectTypes = this.projectTypes || [];
        this.webServices = this.webServices || [];
        
        var webEnabled = this.projectTypes.indexOf(WEB) > -1;
        var desktopEnabled = this.projectTypes.indexOf(DESKTOP) > -1;
        var clickOnceEnabled = this.projectTypes.indexOf(CLICK_ONCE) > -1;
        var windowsServiceEnabled = this.projectTypes.indexOf(WINDOWS_SERVICE) > -1;

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

        if (this.adminTasksEnabled) {
            this.fs.copy(this.templatePath('Scripts/Saritasa.AdminTasks.ps1'), this.destinationPath('Scripts/Saritasa.AdminTasks.ps1'));
            this.installModule('Saritasa.RemoteManagement');
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
});
