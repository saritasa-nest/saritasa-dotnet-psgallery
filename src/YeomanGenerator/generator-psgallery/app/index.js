var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');

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
            choices: ['Web', 'Desktop']
        }]).then(function (answers) {
            this.projectTypes = answers.projectTypes;
        }.bind(this));
    },
    writing: function () {
        mkdirp.sync(this.modulesPath);

        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));

        this.projectTypes = this.projectTypes || [];
        if (this.projectTypes.indexOf('Web') > -1) {
            this.installModule('Saritasa.WebDeploy');
        }
    }
});
