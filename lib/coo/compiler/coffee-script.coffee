coffee = require 'coffee-script'

exports.CoffeeScript = class CoffeeScript
  compile: (source) -> coffee.compile source
