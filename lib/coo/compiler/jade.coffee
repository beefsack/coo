jade = require 'jade'

exports.Jade = class Jade
  compile: (source) -> jade.compile(source, {})({})