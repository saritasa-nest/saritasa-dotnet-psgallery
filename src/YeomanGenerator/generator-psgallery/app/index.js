var generators = require('yeoman-generator');

module.exports = generators.Base.extend({
    initializing: function () {
        console.log('PSGallery generator started.');
    },
    writing: function () {
        this.fs.copy(this.templatePath('default.ps1'), this.destinationPath('default.ps1'));
        this.fs.copy(this.templatePath('Scripts/Saritasa.PsakeTasks.ps1'), this.destinationPath('Scripts/Saritasa.PsakeTasks.ps1'));
    }
});

