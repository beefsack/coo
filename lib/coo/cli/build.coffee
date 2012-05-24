Cli = require '../cli'
Coo = require('../coo').Coo

exports.Build = class Build
  command: 'build [version]'
  description: 'compile and build packages'
  action: (version, cmdr) ->
    (new Coo).build version
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
