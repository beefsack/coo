fs = require 'fs'
path = require 'path'
Builder = require('./builder').Builder

# The CoffeeMug object contains the base functionality of coffee-mug
exports.CoffeeMug = class CoffeeMug
  dir: process.cwd()
  builder: null
  # Builds the source, from compiling to minification
  build: (version) ->
    unless @builder?
      @builder = new Builder
      configPath = path.join @dir, 'config.js'
      @builder.setRootPath @dir
      @builder.loadConfig configPath if path.existsSync configPath
    @builder.build version
  # Gets an equivalent js file name for a coffee file name, handling both .coffee
  # and .js.coffee.
  getJsName: (file) ->
    return file.replace /(\.js)?\.coffee$/, '.js' if file.match /\.coffee$/
    file
