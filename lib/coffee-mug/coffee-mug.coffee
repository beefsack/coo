fs = require 'fs'
path = require 'path'
Builder = require('./builder').Builder
hound = require 'hound'

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
  # Gets an equivalent js file name for a coffee file name, handling both .coffee
  # and .js.coffee.
  getJsName: (file) ->
    return file.replace /(\.js)?\.coffee$/, '.js' if file.match /\.coffee$/
    file
  watch: (version) ->
    console.log "Watching for changes"
    watcher = hound.watch @builder().sourcePath
    cb = =>
      clearTimeout @watchBuffer if @watchBuffer?
      @watchBuffer = setTimeout =>
        @build version
      , 100
    watcher.on 'create', cb
    watcher.on 'change', cb
    watcher.on 'delete', cb
