jasmine = require 'jasmine-node'
wrench = require 'wrench'
util = require 'util'
fs = require 'fs'
path = require 'path'

exports.Jasmine = class Jasmine
  searchExpression: /\.jasmine\./i
  run: (directory) ->
    jasmine.executeSpecsInFolder directory, ->
      console.log '' # Force new line
    , false, true, false, false, @searchExpression
  testsExist: (directory) ->
    for f in wrench.readdirSyncRecursive directory
      f = path.join directory, f
      stat = fs.statSync f
      continue if stat.isDirectory()
      return true if f.match @searchExpression
    false