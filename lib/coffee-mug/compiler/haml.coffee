haml = require 'haml'

exports.Haml = class Haml
  compile: (source) ->
    haml(source)()