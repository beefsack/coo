fs = require 'fs'
path = require 'path'
Builder = require('./builder').Builder
hound = require 'hound'
nodeStatic = require 'node-static'

# The CoffeeMug object contains the base functionality of coffee-mug
exports.CoffeeMug = class CoffeeMug
  dir: process.cwd()
  builderInstance: null
  watchBuffer: null
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
          if err?
            console.error "Error serving #{request.url} - #{err.message}"
            response.writeHead err.status, err.headers
            response.end()
          else
            console.log "#{request.url} - #{res.message}").listen 8080
    console.log "Server is listening on http://127.0.0.1:8080"
