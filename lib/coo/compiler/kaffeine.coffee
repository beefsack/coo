kaffeine = require 'kaffeine'

exports.Kaffeine = class Kaffeine
  compile: (source) ->
    k = new kaffeine
    k.compile source
