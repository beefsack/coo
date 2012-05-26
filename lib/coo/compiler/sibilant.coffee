sibilant = require 'sibilant'
_s = require 'underscore.string'

exports.Sibilant = class Sibilant
  compile: (source) ->
    return '' if _s.trim(source) is ''
    sibilant.translateAll source
