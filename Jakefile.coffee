fs = require 'fs'
path = require 'path'
util = require 'util'
watch = require 'watch'
uglifyJs = require 'uglify-js'
findit = require 'findit'
coffee = require 'coffee-script'
mkdirp = require 'mkdirp'

# CONFIG FILE

configFile = 'config.json'
configFileContents = fs.readFileSync configFile, 'utf8'
config = JSON.parse configFileContents

# CONSTANTS

buildFiles =
  concatenated: "build/#{config.buildName}-concat.js"
  minified: "build/#{config.buildName}-min.js"

# Used to track the watcher timeout, to avoid build spam on mass source changes.
exports.watchTimeout = null
exports.watchTimeoutWaiting = false

# TASKS

desc 'Build the source.'
task 'make', ['compile', 'concat', 'minify']

desc 'Compile from source.'
task 'compile', ->
  console.log 'Compiling source...'
  # Traverse src tree to find old files
  findit.sync 'src', (file) ->
    jake.Task['compile:file'].reenable true
    jake.Task['compile:file'].invoke file
  # Traverse compile trees to prune orphaned files
  console.log 'Pruning orphaned files...'
  orphanedDirs = []
  findit.sync 'build/compiled', (file) ->
    searchPath = file.replace /^build\/compiled/, 'src'
    searchPathCoffee = searchPath.replace /\.js$/, '.coffee'
    return if path.existsSync(searchPath) or path.existsSync(searchPathCoffee)
    fileStats = fs.statSync file
    if fileStats.isFile()
      fs.unlinkSync file
    else if fileStats.isDirectory()
      # Collect directories to remove after files
      orphanedDirs.push file
  fs.rmdir dir for dir in orphanedDirs
  console.log 'Compiled source.'

namespace 'compile', ->
  desc 'Compile a file from source.'
  task 'file', ['build/compiled'], (file) ->
    # Only handle coffee or js files
    extensionCheck = file.match(/\.([^\.]+)$/)
    return unless extensionCheck
    extension = extensionCheck[1]
    return unless ['coffee', 'js'].indexOf(extension) isnt -1
    # Calculate the target so we can check if copy or compilation is required
    if extension is 'coffee'
      target = file.replace(/^src/, 'build/compiled').replace(/\.coffee$/, '.js')
    else
      target = file.replace /^src/, 'build/compiled'
    # Ignore file if the compiled version is newer
    return if path.existsSync(target) and fs.statSync(target).mtime >= fs.statSync(file).mtime
    # Generate contents if required
    if extension is 'coffee'
      console.log "Compiling #{file}..."
      source = fs.readFileSync file, 'utf8'
      contents = coffee.compile source
    # Write the contents, or if no contents we directly copy the file
    mkdirp.sync path.dirname(target)
    if contents?
      console.log "Copying result to #{target}..."
      fs.writeFileSync target, contents
    else
      console.log "Copying #{file} to #{target}..."
      util.pump fs.createReadStream(file), fs.createWriteStream(target)

  desc 'Remove a file from source'
  task 'remove', (file) ->
    console.log "Removing #{file}..."

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
  console.log 'Minifying source...'
  concatenated = fs.readFileSync buildFiles.concatenated, 'utf8'
  jsp = uglifyJs.parser
  pro = uglifyJs.uglify
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
  console.log 'Watching for changes...'
  watch.watchTree 'src', (f, curr, prev) ->
    return unless typeof f is 'string'
    unless prev? and curr.nlink is 0
      console.log "#{f} updated."
    else
      console.log "#{f} removed."
    clearTimeout exports.watchTimeout if exports.watchTimeoutWaiting
    exports.watchTimeoutWaiting = true
    exports.watchTimeout = setTimeout ->
      jake.Task['make'].reenable true
      jake.Task['make'].invoke()
      exports.watchTimeoutWaiting = false
    , 500

# DIRECTORIES

directory 'build'
directory 'build/compiled', ['build']
