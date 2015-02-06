module.exports = function(grunt) {
  grunt.initConfig({
    'build-atom-shell': {
      tag: 'v0.21.1',
      // nodeVersion: '0.20.0',
      buildDir: 'build',
      projectName: 'maid',
      productName: 'Maid'
    }
  });
  grunt.loadNpmTasks('grunt-build-atom-shell');
  grunt.registerTask('default', ['build-atom-shell']);
};
