fs = require 'fs'
path = require 'path'
XRegExp = require('xregexp').XRegExp
mkdirp = require 'mkdirp'
walkdir = require 'walkdir'
_ = require 'underscore'
util = require 'util'
# Compilers
Coco = require('./compiler/coco').Coco
CoffeeScript = require('./compiler/coffee-script').CoffeeScript
Haml = require('./compiler/haml').Haml
Jade = require('./compiler/jade').Jade
Less = require('./compiler/less').Less
Stylus = require('./compiler/stylus').Stylus
Markdown = require('./compiler/markdown').Markdown

exports.Builder = class Builder
  sourcePath: null
  compilePath: null
  outputPath: null
  defaultVersion: 'development'
  compileConfigTree: {}
  postConfigTree: {}
  # Versions are created in the output path, the first version is build default
  versions:
    development:
      postProcess: false
    production: {}
  files: {}
  compilePaths: [
    {
      # Default config
      path: '**'
      targetFile: (file) -> file
    }
    # JS compilers
    {
      # CoffeeScript
      path: '**.coffee'
      compiler: new CoffeeScript
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.js)?\.coffee/, '.js' else file
    }
    {
      # Coco
      path: '**.co'
      compiler: new Coco
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.js)?\.co/, '.js' else file
    }
    # HTML compilers
    {
      # Haml
      path: '**.haml'
      compiler: new Haml
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.html)?\.haml/, '.html' else file
    }
    {
      # Jade
      path: '**.jade'
      compiler: new Jade
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.html)?\.jade/, '.html' else file
    }
    {
      # Markdown
      path: '**.md'
      compiler: new Markdown
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.html)?\.md/, '.html' else file
    }
    # CSS compilers
    {
      # LESS
      path: '**.less'
      compiler: new Less
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.css)?\.less/, '.css' else file      
    }
    # {
    #   # SCSS and SASS
    #   path: [ '**.sass', '**.scss' ]
    #   compiler: new Scss
    #   compile: true
    #   targetFile: (file) ->
    #     if @compile then file.replace /(\.css)?\.s[ac]ss/, '.css' else file      
    # }
    {
      # Stylus
      path: '**.styl'
      compiler: new Stylus
      compile: true
      targetFile: (file) ->
        if @compile then file.replace /(\.css)?\.styl/, '.css' else file      
    }
  ]
  postPaths: []
  # Load in a config file and run the config's 'config' function for this
  loadConfig: (file) =>
    require(file).config this
  # Create a file builder given options
  buildFile: (file, options) ->
    @files[file] = options
  # Set pre compile config for a path
  compileConfig: (p, options) ->
    options.path = p
    @compilePaths.push options
  # Set post compile config for a path
  postConfig: (p, options) ->
    options.path = p
    @postPaths.push options
  parseWildcardPath: (p) ->
    escaped = p.split('*').map( (s) -> XRegExp.escape(s)).join '*'
    converted = escaped.replace('**', '.*').replace /(.?)(.?)\*/g, ($0, $1, $2) ->
      if $2 isnt '.' or $1 isnt '\\' then $0 else "#{$1}#{$2}[^/\\\\]*"
    new RegExp "^#{converted}$"
  # Check if a path (needle) matches another string, RegExp or array of paths
  matchPath: (needle, haystack) ->
    # Array case
    if _.isArray haystack
      for hs in haystack
        return true if @matchPath needle, hs
      return false
    # Single case
    haystack = @parseWildcardPath haystack unless _.isRegExp haystack
    return haystack.test(needle)
  # Build the source tree
  setRootPath: (p) ->
    @sourcePath = path.join p, 'src'
    @compilePath = path.join p, 'tmp/compiled'
    @outputPath = path.join p, 'build'
  build: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    @compile() unless @versions[version].compile is false
    @buildFiles() unless @versions[version].buildFiles is false
    unless @versions[version].postProcess is false
      @postProcess()
    console.log 'build'
  compile: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    console.log 'Compiling...'
    # Create new files when required
    targets = []
    for f, conf of @generateCompileConfigTree(version)
      sourceFile = path.join @sourcePath, f
      targetFile = path.join @compilePath, version, conf.targetFile(f)
      targets.push targetFile unless conf.ignore is true
      unless conf.ignore
        if not path.existsSync(targetFile) or fs.statSync(targetFile).mtime <
        fs.statSync(sourceFile).mtime
          if conf.compile
            console.log "Compiling #{f}..."
            source = fs.readFileSync sourceFile, 'utf8'
            fs.writeFileSync targetFile, conf.compiler.compile(source)
          else
            console.log "Copying #{f}..."
            mkdirp.sync path.dirname(targetFile)
            util.pump fs.createReadStream(sourceFile), fs.createWriteStream(targetFile)
    # Prune orphaned files
    walkdir.sync path.join(@compilePath, version), (f, stat) ->
      return if stat.isDirectory()
      if targets.indexOf(f) is -1
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync f

  buildFiles: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    console.log 'build files'
  postProcess: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    console.log 'post process'
  generateCompileConfigTree: (version) ->
    @compileConfigTree[version] = {} unless @compileConfigTree[version]
    # Prune missing items from the tree
    for f in _.keys @compileConfigTree[version]
      abs = path.join @sourcePath, f
      delete @compileConfigTree[version][f] unless path.existsSync abs
    # Add new items to the tree
    walkdir.sync @sourcePath, (f, stat) =>
      # Trim source dir off path
      return if stat.isDirectory()
      f = f.replace(@sourcePath, '')
      f = f.substring(1, f.length)
      return if @compileConfigTree[version][f]?
      for cp in @compilePaths when @matchPath f, cp.path
        pathConf = @compileConfigTree[version][f] or {}
        pathConf = _.defaults cp, pathConf
        @compileConfigTree[version][f] = pathConf
    @compileConfigTree[version]
  generatePostConfigTree: (version) ->
    @postConfigTree[version] = {} unless @postConfigTree[version]