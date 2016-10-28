var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');

const WEB = 'Web';
const DESKTOP = 'Desktop';
const CLICK_ONCE = 'ClickOnce';
const WINDOWS_SERVICE = 'Windows Service';

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
    },
    prompting: function () {
        return this.prompt([{
            type: 'checkbox',
            name: 'projectTypes',
            message: 'Select all used project types:',
            choices: [WEB, DESKTOP, CLICK_ONCE, WINDOWS_SERVICE]
        }]).then(function (answers) {
            this.projectTypes = answers.projectTypes;
        }.bind(this));
    },
    writing: function () {
        mkdirp.sync(this.modulesPath);

        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));

        this.projectTypes = this.projectTypes || [];
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
    }
});
