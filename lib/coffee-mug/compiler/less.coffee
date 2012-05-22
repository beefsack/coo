less = require 'less'

exports.Less = class Less
  compile: (source) ->
    content = null
    until content?
      less.render source, (e, root) ->
        throw e if e?
        content = root
    return content
