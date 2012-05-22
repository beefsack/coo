exports.config = function(config) {
  // Build all css in the css directory down to a single file
  config.buildFile('css/style.css', {
    source: 'css/**.css'
  });
  // Build all js in the js directory down to a single file
  config.buildFile('js/script.js', {
    source: 'js/**.js'
  });
  // Don't alter files in the lib directory
  config.compileConfig('lib/**', {
    compile: false
  });
  config.postConfig('lib/**', {
    process: false
  });
  // Ignore includes directory and contents, compile time helpers can go here
  config.compileConfig('includes**', {
    ignore: true
  });
  // Ignore .gitkeep files
  config.compileConfig('**/.gitkeep', {
    ignore: true
  });
}
