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
IcedCoffeeScript = require('./compiler/iced-coffee-script').IcedCoffeeScript
Kaffeine = require('./compiler/kaffeine').Kaffeine
Move = require('./compiler/move').Move
Haml = require('./compiler/haml').Haml
Jade = require('./compiler/jade').Jade
Less = require('./compiler/less').Less
Stylus = require('./compiler/stylus').Stylus
Markdown = require('./compiler/markdown').Markdown
# Processors
UglifyJs = require('./processor/uglify-js').UglifyJs
CleanCss = require('./processor/clean-css').CleanCss

generateCompilerConfig = (compiler, extension, target) ->
  path: "**.#{extension}"
  compiler: compiler
  compile: true
  targetFile: (file) ->
    repRegex = new RegExp "(.#{target})?\\.#{extension}$"
    if @compile then file.replace repRegex, ".#{target}" else file            

exports.Builder = class Builder
  sourcePath: null
  compilePath: null
  outputPath: null
  defaultVersion: 'development'
  compileConfigTree: {}
  postConfigTree: {}
  fileConfigTree: {}
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
    generateCompilerConfig new CoffeeScript, 'coffee', 'js'
    generateCompilerConfig new IcedCoffeeScript, 'iced', 'js'
    generateCompilerConfig new Coco, 'co', 'js'
    generateCompilerConfig new Kaffeine, 'k', 'js'
    generateCompilerConfig new Move, 'mv', 'js'
    # HTML compilers
    generateCompilerConfig new Haml, 'haml', 'html'
    generateCompilerConfig new Jade, 'jade', 'html'
    generateCompilerConfig new Markdown, 'md', 'html'
    # CSS compilers
    generateCompilerConfig new Less, 'less', 'css'
    generateCompilerConfig new Stylus, 'styl', 'css'
  ]
  postPaths: [
    {
      # Mangle and compress JS
      path: '**.js'
      process: true
      processors: [
        new UglifyJs
      ]
    }
    {
      # Compress CSS
      path: '**.css'
      process: true
      processors: [
        new CleanCss
      ]
    }
  ]
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
    @compile version unless @versions[version].compile is false
    @buildFiles version unless @versions[version].buildFiles is false
    @postProcess version unless @versions[version].postProcess is false
  compile: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    # Create new files when required
    targets = []
    for f, conf of @generateCompileConfigTree(version)
      sourceFile = path.join @sourcePath, f
      targetFile = path.join @compilePath, version, conf.targetFile(f)
      targets.push targetFile unless conf.ignore is true
      unless conf.ignore
        if not path.existsSync(targetFile) or fs.statSync(targetFile).mtime <
        fs.statSync(sourceFile).mtime
          mkdirp.sync path.dirname(targetFile)
          if conf.compile
            console.log "Compiling #{f}..."
            source = fs.readFileSync sourceFile, 'utf8'
            fs.writeFileSync targetFile, conf.compiler.compile(source)
          else
            console.log "Copying #{f}..."
            fs.writeFileSync targetFile, fs.readFileSync(sourceFile)
    # Prune orphaned files
    buildFileNames = []
    for bf in _.keys @files
      buildFileNames.push path.join(@compilePath, version, bf)
    walkdir.sync path.join(@compilePath, version), (f, stat) ->
      return if stat.isDirectory()
      if targets.indexOf(f) is -1 and buildFileNames.indexOf(f) is -1
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync f
  buildFiles: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    builtFiles = []
    compiledFiles = []
    cvPath = path.join @compilePath, version
    for c, f of @generateCompileConfigTree() when not f.ignore
      compiledFiles.push f.targetFile(c)
    for bf, bfConf of @files
      # Check if we need update, searching sources one by one to get correct
      # dependency order
      bfPath = path.join @compilePath, version, bf
      sources = [bfConf.source] unless _.isArray bfConf.source
      matchedFiles = []
      requiresBuild = false
      for s in sources
        for cf in compiledFiles when (matchedFiles.indexOf cf is -1) and
        @matchPath cf, s
          cfPath = path.join cvPath, cf
          throw "Cannot find compiled file #{cf}" unless path.existsSync cfPath
          matchedFiles.push cfPath
          builtFiles.push cf
          if not requiresBuild and (not path.existsSync(bfPath) or
          fs.statSync(cfPath).mtime > fs.statSync(bfPath).mtime)
            requiresBuild = true
      if requiresBuild
        console.log "Building #{bf}..."
        mkdirp.sync path.dirname(bfPath)
        bfFile = fs.openSync bfPath, 'w'
        for mf in matchedFiles
          fs.writeSync(bfFile, fs.readFileSync(mf, 'utf8'), null)
      compiledFiles.push bf
    # Move files to build dir
    ovPath = path.join(@outputPath, version)
    mkdirp.sync ovPath
    buildFileNames = _.keys @files
    walkdir.sync cvPath, (f, stat) ->
      return if stat.isDirectory()
      f = path.relative(cvPath, f)
      outf = path.join ovPath, f
      if builtFiles.indexOf(f) is -1 or buildFileNames.indexOf(f) isnt -1
        compf = path.join cvPath, f
        if not path.existsSync(outf) or
        fs.statSync(outf).mtime < fs.statSync(compf).mtime
          # Copy
          console.log "Outputting #{f}..."
          mkdirp.sync path.dirname(outf)
          fs.writeFileSync outf, fs.readFileSync(compf)
      else if path.existsSync(outf)
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync outf
    # Prune orphaned files
    walkdir.sync ovPath, (f, stat) ->
      return if stat.isDirectory()
      relf = path.relative(ovPath, f)
      unless path.existsSync(path.join(cvPath, relf))
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync f
  postProcess: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    return if @versions[version].postProcess is false
    # Run processors
    ovPath = path.join @outputPath, version
    for f, c of @generatePostConfigTree(version) when not c.ignore
      if c.process
        p = path.join ovPath, f
        source = fs.readFileSync p, 'utf8'
        source = processor.process(source) for processor in c.processors
        fs.writeFileSync p, source
  generateCompileConfigTree: ->
    @generateFileConfigTree @sourcePath, @compilePaths
  generatePostConfigTree: (version) ->
    @generateFileConfigTree path.join(@outputPath, version), @postPaths
  generateFileConfigTree: (p, configs) ->
    cJson = JSON.stringify configs
    @fileConfigTree[p] = {} unless @fileConfigTree[p]?
    @fileConfigTree[p][cJson] = {} unless @fileConfigTree[p][cJson]?
    # Prune missing items from the tree
    for f in _.keys @fileConfigTree[p][cJson]
      abs = path.join @sourcePath, f
      delete @fileConfigTree[p][cJson][f] unless path.existsSync abs
    # Add new items to the tree
    walkdir.sync p, (f, stat) =>
      # Trim source dir off path
      return if stat.isDirectory()
      f = path.relative(p, f)
      return if @fileConfigTree[p][cJson][f]?
      for c in configs when @matchPath f, c.path
        pathConf = @fileConfigTree[p][cJson][f] or {}
        pathConf = _.defaults c, pathConf
        @fileConfigTree[p][cJson][f] = pathConf
    @fileConfigTree[p][cJson]  
  # Link to top level, made accessible inside the object for configuration.
  generateCompilerConfig: generateCompilerConfig
