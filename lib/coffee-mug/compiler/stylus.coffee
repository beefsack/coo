stylus = require 'stylus'

exports.Stylus = class Stylus
  compile: (source) ->
    output = null
    until output?
      stylus.render source, {}, (err, css) =>
        throw err if err?
        output = css
    return output