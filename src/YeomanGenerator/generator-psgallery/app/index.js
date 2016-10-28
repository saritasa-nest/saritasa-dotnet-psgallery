var generators = require('yeoman-generator');
var mkdirp = require('mkdirp');

module.exports = generators.Base.extend({
    initializing: function () {
        console.log('PSGallery generator started.');
    },
    prompting: function () {
        return this.prompt([{
            type: 'list',
            name: 'projectType',
            message: 'Project type',
            choices: ['Web', 'Desktop']
        }]).then(function (answers) {
            this.projectType = answers.projectType;
        }.bind(this));
    },
    writing: function () {
        var modulesPath = this.destinationPath('scripts/modules')
        mkdirp.sync(modulesPath);

        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));

        if (this.projectType === 'Web') {
            this.spawnCommand('powershell', ['-Command', '&{ Save-Module Saritasa.WebDeploy -Path ' + modulesPath + ' }']);
        }
    }
});

