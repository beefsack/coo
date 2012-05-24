roy = require 'roy'

exports.Roy = class Roy
  compile: (source) -> roy.compile(source).output
