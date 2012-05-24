uglifyJs = require 'uglify-js'

exports.UglifyJs = class UglifyJs
  mangle: true
  squeeze: true
  constructor: (options) ->
    options = {} unless options?
    @mangle = options.mangle if options.mangle?
    @squeeze = options.squeeze if options.squeeze?
  process: (source) ->
    jsp = uglifyJs.parser
    pro = uglifyJs.uglify
    ast = jsp.parse source
    ast = pro.ast_mangle(ast) if @mangle
    ast = pro.ast_squeeze(ast) if @squeeze
    pro.gen_code ast
