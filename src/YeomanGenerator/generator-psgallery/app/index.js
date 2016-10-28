var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');

module.exports = generators.Base.extend({
    initializing: function () {
        console.log('PSGallery generator started.');
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
        var modulesPath = this.destinationPath('scripts/modules')
        mkdirp.sync(modulesPath);

        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));

        this.projectTypes = this.projectTypes || [];
        if (this.projectTypes.indexOf('Web') > -1) {
            this.spawnCommand('powershell', ['-Command', '&{ Save-Module Saritasa.WebDeploy -Path ' + modulesPath + ' }']);
        }
    }
});

