Cli = require '../cli'
CoffeeMug = require('../coffee-mug').CoffeeMug

exports.Build = class Build
  command: 'build [version]'
  description: 'compile and build packages'
  action: (version, cmdr) ->
    (new CoffeeMug).build version
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
