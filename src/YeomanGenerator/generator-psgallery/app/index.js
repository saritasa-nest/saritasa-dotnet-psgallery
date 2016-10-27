var generators = require('yeoman-generator');

module.exports = generators.Base.extend({
    initializing: function () {
        console.log('PSGallery generator started.');
    }
});

