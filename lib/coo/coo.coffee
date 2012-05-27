fs = require 'fs'
path = require 'path'
Builder = require('./builder').Builder
hound = require 'hound'
nodeStatic = require 'node-static'
wrench = require 'wrench'
util = require 'util' # Required by wrench
# Languages for tests
require 'coco'
require 'contracts.coffee'
require 'iced-coffee-script'
require 'kaffeine'
require 'move-panta'
require 'roy'
require 'sibilant'
# Testers
Jasmine = require('./tester/jasmine').Jasmine

# The Coo class contains the base functionality of Coo
exports.Coo = class Coo
  dir: process.cwd()
  builderInstance: null
  watchBuffer: null
  testers: [
    new Jasmine
  ]
  builder: ->
    unless @builderInstance?
      @builderInstance = new Builder
      configPath = path.join @dir, 'config.js'
      @builderInstance.setRootPath @dir
      @builderInstance.loadConfig configPath if path.existsSync configPath
    @builderInstance
  # Builds the source, from compiling to minification
  build: (version) ->
    @builder().build version
  watch: (version) ->
    @build version
    watcher = hound.watch @builder().sourcePath
    cb = =>
      clearTimeout @watchBuffer if @watchBuffer?
      @watchBuffer = setTimeout =>
        @build version
      , 100
    watcher.on 'create', cb
    watcher.on 'change', cb
    watcher.on 'delete', cb
  server: (version) ->
    # Start a server, then watch
    version = @builder().defaultVersion unless version?
    @watch version
    file = new nodeStatic.Server path.join(@builder().outputPath, version),
      cache: false
    require('http').createServer( (request, response) ->
      request.addListener 'end', ->
        file.serve request, response, (err, res) ->
          if err? and not request.url.match /favicon\.ico/
            console.error "Error serving #{request.url} - #{err.message}"
            response.writeHead err.status, err.headers
            response.end()).listen 16440
    console.log "Server is listening on http://127.0.0.1:16440"
  init: (location) ->
    location = process.cwd() unless location?
    wrench.copyDirSyncRecursive path.join(__dirname, '../../share/init'), location
    console.log "Initialised coo project at #{location}"
  test: (directory) ->
    directory = path.join process.cwd(), 'test' unless directory?
    for tester in @testers
      tester.run directory if tester.testsExist directory
