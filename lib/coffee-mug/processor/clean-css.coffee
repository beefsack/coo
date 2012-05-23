cleanCSS = require 'clean-css'

exports.CleanCss = class CleanCss
  process: (source) ->
    cleanCSS.process source
