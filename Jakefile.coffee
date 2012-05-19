fs = require 'fs'
watch = require 'watch'

# CONFIG FILE

configFile = 'config.json'
configFileContents = fs.readFileSync configFile, 'utf8'
config = JSON.parse configFileContents

# CONSTANTS

buildFiles =
  concatenated: "build/#{config.buildName}-concat.js"
  minified: "build/#{config.buildName}-min.js"

# TASKS

desc 'Build the source.'
task 'make', ['compile', 'concat', 'minify']

desc 'Compile from source.'
task 'compile', ['clean', 'build/compiled'], ->
  console.log 'Compiling source...'
  jake.exec ['coffee -o build/compiled/ -c src/'], ->
    console.log 'Successfully compiled source.'
    complete()
, {async: true}

desc 'Build concatenated source.'
task 'concat', ->
  jake.Task['compile'].invoke()
  console.log 'Concatenating compiled source...'
  jake.exec ["find build/compiled/ -name *.js | xargs cat > #{buildFiles.concatenated}"], ->
    console.log 'Successfully concatenated compiled source.'
    complete()
, {async: true}

desc 'Build minified source.'
task 'minify', ->
  jsp = require("uglify-js").parser;
  pro = require("uglify-js").uglify;
  console.log 'Minifying source...'
  concatenated = fs.readFileSync buildFiles.concatenated, 'utf8'
  ast = jsp.parse concatenated
  ast = pro.ast_mangle ast
  ast = pro.ast_squeeze ast
  minified = pro.gen_code ast
  fs.writeFileSync buildFiles.minified, minified
  console.log 'Successfully minified source.'

desc 'Clean build directory.'
task 'clean', ['build/compiled'], ->
  console.log 'Cleaning build directory...'
  jake.exec ['rm -rfv build/compiled/*'], ->
    console.log 'Successfully cleaned build directory.'
    complete()
, {async: true}

desc 'Watch the source directory and make whenever source changes.'
task 'watch', ['make'], ->
  watch.watchTree 'src', (f, curr, prev) ->
    return unless f.match? and f.match /\.coffee$/
    unless prev?
      console.log "#{f} created, rebuilding..."
    else if curr.nlink is 0
      console.log "#{f} removed, rebuilding..."
    else
      console.log "#{f} changed, rebuilding..."
    jake.Task['make'].reenable true
    jake.Task['make'].invoke()

# DIRECTORIES

directory 'build'
directory 'build/compiled', ['build']
