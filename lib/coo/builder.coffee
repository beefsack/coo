fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
XRegExp = require('xregexp').XRegExp
_ = require 'underscore'
wrench = require 'wrench'
util = require 'util' # Required by wrench
growl = require 'growl'
# Compilers
Coco = require('./compiler/coco').Coco
CoffeeScript = require('./compiler/coffee-script').CoffeeScript
IcedCoffeeScript = require('./compiler/iced-coffee-script').IcedCoffeeScript
Kaffeine = require('./compiler/kaffeine').Kaffeine
Move = require('./compiler/move').Move
Sibilant = require('./compiler/sibilant').Sibilant
Haml = require('./compiler/haml').Haml
Jade = require('./compiler/jade').Jade
Markdown = require('./compiler/markdown').Markdown
Less = require('./compiler/less').Less
Stylus = require('./compiler/stylus').Stylus
# Processors
UglifyJs = require('./processor/uglify-js').UglifyJs
CleanCss = require('./processor/clean-css').CleanCss

generateCompilerConfig = (compiler, extension, target) ->
  path: "**.#{extension}"
  compiler: compiler
  compile: true
  targetFile: (file) ->
    repRegex = new RegExp "(\\.#{target})?\\.#{extension}$"
    if @compile then file.replace repRegex, ".#{target}" else file
exports.Builder = class Builder
  sourcePath: null
  tmpPath: null
  outputPath: null
  compileDir: 'compiled'
  srcHashDb: 'src-hash'
  compileHashDb: 'compile-hash'
  buildFileHashDb: 'build-file-hash'
  copyFileHashDb: 'copy-file-hash'
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
    generateCompilerConfig new Sibilant, 'sibilant', 'js'
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
    @tmpPath = path.join p, 'tmp'
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
    srcHashes = @loadDatabase version, @srcHashDb
    compilePath = @getCompilePath version
    wrench.mkdirSyncRecursive compilePath
    for f, conf of @generateCompileConfigTree(version)
      sourceFile = path.join @sourcePath, f
      targetFile = path.join compilePath, conf.targetFile(f)
      targets.push targetFile unless conf.ignore is true
      unless conf.ignore
        srcHash = @getFileHash sourceFile
        unless fs.existsSync(targetFile) and srcHashes[sourceFile] is srcHash
          wrench.mkdirSyncRecursive path.dirname(targetFile)
          if conf.compile
            console.log "Compiling #{f}..."
            source = fs.readFileSync sourceFile, 'utf8'
            try
              compiled = conf.compiler.compile(source)
            catch e
              title = "Error while compiling #{f}"
              errorMesage = "#{title}\n#{e.toString()}"
              console.log errorMesage
              growl e.toString(),
                title: title
                name: 'coo'
              continue
            fs.writeFileSync targetFile, compiled
          else
            console.log "Copying #{f}..."
            fs.writeFileSync targetFile, fs.readFileSync(sourceFile)
          srcHashes[sourceFile] = srcHash
          @saveDatabase version, @srcHashDb, srcHashes
    # Prune orphaned files
    buildFileNames = []
    for bf in _.keys @files
      buildFileNames.push path.join(compilePath, bf)
    for f in wrench.readdirSyncRecursive compilePath
      f = path.join compilePath, f
      stat = fs.statSync f
      continue if stat.isDirectory()
      if targets.indexOf(f) is -1 and buildFileNames.indexOf(f) is -1
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync f
  buildFiles: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    builtFiles = []
    compiledFiles = []
    cvPath = @getCompilePath version
    buildFileHashes = @loadDatabase version, @buildFileHashDb
    for c, f of @generateCompileConfigTree() when not f.ignore
      compiledFiles.push f.targetFile(c)
    for bf, bfConf of @files
      # Check if we need update, searching sources one by one to get correct
      # dependency order
      bfPath = path.join cvPath, bf
      sources = bfConf.source
      sources = [sources] unless _.isArray sources
      matchedFiles = []
      matchedFileHashes = []
      requiresBuild = false
      for s in sources
        for cf in compiledFiles when (matchedFiles.indexOf cf is -1) and
        @matchPath cf, s
          cfPath = path.join cvPath, cf
          throw "Cannot find compiled file #{cf}" unless fs.existsSync cfPath
          matchedFiles.push cfPath
          matchedFileHashes.push @getFileHash(cfPath)
          builtFiles.push cf
      buildFileExists = fs.existsSync bfPath
      if buildFileExists and matchedFiles.length is 0
        console.log "Removing #{bf}..."
        fs.unlinkSync bfPath
      else if matchedFiles.length > 0
        newMatchedFilesHash = @getHash matchedFileHashes.join()
        unless fs.existsSync(bfPath) and
        buildFileHashes[bfPath] is newMatchedFilesHash
          console.log "Building #{bf}..."
          wrench.mkdirSyncRecursive path.dirname(bfPath)
          bfFile = fs.openSync bfPath, 'w'
          # console.log matchedFiles
          for mf in matchedFiles
            fs.writeSync(bfFile, fs.readFileSync(mf, 'utf8'), null)
          buildFileHashes[bfPath] = newMatchedFilesHash
          @saveDatabase version, @buildFileHashDb, buildFileHashes
      compiledFiles.push bf
    # Move files to build dir
    copyFileHashes = @loadDatabase version, @copyFileHashDb
    ovPath = path.join(@outputPath, version)
    wrench.mkdirSyncRecursive ovPath
    buildFileNames = _.keys @files
    for f in wrench.readdirSyncRecursive cvPath
      f = path.join cvPath, f
      stat = fs.statSync f
      continue if stat.isDirectory()
      f = path.relative(cvPath, f)
      outf = path.join ovPath, f
      if builtFiles.indexOf(f) is -1 or buildFileNames.indexOf(f) isnt -1
        compf = path.join cvPath, f
        compfHash = @getFileHash compf
        unless fs.existsSync(outf) and
        copyFileHashes[compf] is compfHash
          # Copy
          console.log "Outputting #{f}..."
          wrench.mkdirSyncRecursive path.dirname(outf)
          fs.writeFileSync outf, fs.readFileSync(compf)
          copyFileHashes[compf] = compfHash
          @saveDatabase version, @copyFileHashDb, copyFileHashes          
      else if fs.existsSync(outf)
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync outf
    # Prune orphaned files
    for f in wrench.readdirSyncRecursive ovPath
      f = path.join ovPath, f
      stat = fs.statSync f
      continue if stat.isDirectory()
      relf = path.relative(ovPath, f)
      unless fs.existsSync(path.join(cvPath, relf))
        console.log "Removing orphaned file #{f}..."
        fs.unlinkSync f
  postProcess: (version) ->
    version = @defaultVersion unless version?
    throw "#{version} is not a valid version name" unless @versions[version]?
    return if @versions[version].postProcess is false
    # Run processors
    ovPath = @getOutputPath version
    for f, c of @generatePostConfigTree(version) when not c.ignore
      if c.process
        p = path.join ovPath, f
        source = fs.readFileSync p, 'utf8'
        try
          source = processor.process(source) for processor in c.processors
        catch e
          console.log "Error while processing #{f}:"
          console.log e.toString()          
          continue
        fs.writeFileSync p, source
  generateCompileConfigTree: ->
    @generateFileConfigTree @sourcePath, @compilePaths
  generatePostConfigTree: (version) ->
    @generateFileConfigTree @getOutputPath(version), @postPaths
  generateFileConfigTree: (p, configs) ->
    cJson = JSON.stringify configs
    @fileConfigTree[p] = {} unless @fileConfigTree[p]?
    @fileConfigTree[p][cJson] = {} unless @fileConfigTree[p][cJson]?
    # Prune missing items from the tree
    for f in _.keys @fileConfigTree[p][cJson]
      abs = path.join @sourcePath, f
      delete @fileConfigTree[p][cJson][f] unless fs.existsSync abs
    # Add new items to the tree
    for f in wrench.readdirSyncRecursive p
      f = path.join p, f
      stat = fs.statSync f
      # Trim source dir off path
      continue if stat.isDirectory()
      f = path.relative(p, f)
      continue if @fileConfigTree[p][cJson][f]?
      for c in configs when @matchPath f, c.path
        pathConf = @fileConfigTree[p][cJson][f] or {}
        pathConf = _.defaults c, pathConf
        @fileConfigTree[p][cJson][f] = pathConf
    @fileConfigTree[p][cJson]
  getHash: (data) ->
    hash = crypto.createHash 'sha1'
    hash.update data
    hash.digest 'base64'
  getFileHash: (file) -> @getHash fs.readFileSync(file, 'utf8')
  getCompilePath: (version) -> path.join @tmpPath, version, @compileDir
  getOutputPath: (version) -> path.join @outputPath, version
  getDatabaseFileName: (version, name) ->
    "#{path.join(@tmpPath, version, name)}.json"
  loadDatabase: (version, name) ->
    file = @getDatabaseFileName version, name
    return {} unless fs.existsSync file
    JSON.parse fs.readFileSync(file, 'utf8')
  saveDatabase: (version, name, data) ->
    file = @getDatabaseFileName version, name
    fs.writeFileSync file, JSON.stringify(data)
  # Link to top level, made accessible inside the object for configuration.
  generateCompilerConfig: generateCompilerConfig
