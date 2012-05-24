marked = require 'marked'

exports.Markdown = class Markdown
  compile: (source) -> marked source