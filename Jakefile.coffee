fs = require 'fs'
path = require 'path'
util = require 'util'
watch = require 'watch'
uglifyJs = require 'uglify-js'
findit = require 'findit'
coffee = require 'coffee-script'
mkdirp = require 'mkdirp'
jasmine = require 'jasmine-node'
coffeeMug = require './lib/coffee-mug/coffee-mug'

# CONFIG FILE

configFile = 'config.json'
configFileContents = fs.readFileSync configFile, 'utf8'
config = JSON.parse configFileContents

# TASKS

desc 'Build the source.'
task 'make', ['compile', 'concat', 'minify']

desc 'Compile from source.'
task 'compile', ->
  console.time 'Compile'
  console.log 'Compiling source...'
  # Traverse src tree to find old files
  findit.sync 'src', (file) ->
    jake.Task['compile:file'].reenable true
    jake.Task['compile:file'].invoke file
  # Traverse compile trees to prune orphaned files
  console.log 'Pruning orphaned files...'
  orphanedDirs = []
  findit.sync 'build/compiled', (file) ->
    # Build some path candidates and check if it exists in the source.
    searchPath = file.replace /^build\/compiled/, 'src'
    pathCandidates = [
      searchPath
      "#{searchPath}.coffee"
      searchPath.replace(/\.js$/, '.coffee')
    ]
    existsInSrc = false
    existsInSrc = existsInSrc or path.existsSync(p) for p in pathCandidates
    # We found it in src, so we leave it
    return if existsInSrc
    # Check if it is a file or a directory and handle appropriately
    fileStats = fs.statSync file
    if fileStats.isFile()
      fs.unlinkSync file
    else if fileStats.isDirectory()
      # Collect directories to remove after files
      orphanedDirs.push file
  fs.rmdir dir for dir in orphanedDirs
  console.timeEnd 'Compile'

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
      target = coffeeMug.getJsName file.replace(/^src/, 'build/compiled')
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
task 'concat', (buildPackage) ->
  unless buildPackage?
    # No buildPackage was specified, so loop over all packages in the config
    for name, c of config.buildPackages
      jake.Task['concat'].reenable true
      jake.Task['concat'].invoke name
    return
  console.time 'Concatenate'
  console.log "Concatenating compiled source for #{buildPackage}..."
  loadFiles = []
  # First build a list of files to load, ignoring duplicates
  for source in config.buildPackages[buildPackage].sources
    sourcePath = path.normalize "build/compiled/#{source}"
    sourcePathStats = fs.statSync sourcePath
    if sourcePathStats.isFile()
      loadFiles.push sourcePath if loadFiles.indexOf(sourcePath) is -1
    else if sourcePathStats.isDirectory()
      findit.sync sourcePath, (file) ->
        loadFiles.push file if file.match(/\.js$/) and loadFiles.indexOf(file) is -1
  # Iterate over files to load and concatenate them
  concatData = ''
  for file in loadFiles
    concatData += fs.readFileSync file, 'utf8'
  fs.writeFileSync "build/#{buildPackage}-concat.js", concatData
  console.timeEnd 'Concatenate'

desc 'Build minified source.'
task 'minify', (buildPackage) ->
  unless buildPackage?
    # No buildPackage was specified, so loop over all packages in the config
    for name, c of config.buildPackages
      jake.Task['minify'].reenable true
      jake.Task['minify'].invoke name
    return
  console.time 'Minify'
  console.log "Minifying source for #{buildPackage}..."
  concatenated = fs.readFileSync "build/#{buildPackage}-concat.js" , 'utf8'
  jsp = uglifyJs.parser
  pro = uglifyJs.uglify
  ast = jsp.parse concatenated
  ast = pro.ast_mangle ast
  ast = pro.ast_squeeze ast
  minified = pro.gen_code ast
  fs.writeFileSync "build/#{buildPackage}-min.js", minified
  console.timeEnd 'Minify'

desc 'Clean build directory.'
task 'clean', ['build/compiled'], ->
  console.log 'Cleaning build directory...'
  jake.exec ['rm -rfv build'], ->
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
    # This is run with a timeout to avoid build spam, such as when moving and
    # deleting a large amount of files.  The timer is reset whenever a request
    # is made inside the timeout period.
    clearTimeout coffeeMug.watchTimeout if coffeeMug.watchTimeoutWaiting
    coffeeMug.watchTimeoutWaiting = true
    coffeeMug.watchTimeout = setTimeout ->
      jake.Task['make'].reenable true
      jake.Task['make'].invoke()
      coffeeMug.watchTimeoutWaiting = false
    , 100

desc 'Run the tests in the spec directory.'
task 'test', ->
  onComplete = (runner, log) ->
  jasmine.executeSpecsInFolder 'spec', onComplete, false, true

namespace 'test', ->
  desc 'Run the tests for coffee-mug.'
  task 'coffeeMug', ->
    onComplete = ->
    jasmine.executeSpecsInFolder 'lib/coffee-mug/spec', onComplete, false, true

# DIRECTORIES

directory 'build'
directory 'build/compiled', ['build']
