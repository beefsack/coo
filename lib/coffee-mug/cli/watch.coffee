Cli = require '../cli'
CoffeeMug = require('../coffee-mug').CoffeeMug

exports.Watch = class Watch
  command: 'watch [version]'
  description: 'watch for source changes and compile on the fly'
  action: (version, cmdr) ->
    (new CoffeeMug).watch version
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
