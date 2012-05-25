Cli = require '../cli'
Coo = require('../coo').Coo

exports.Init = class Init
  command: 'init [directory]'
  description: 'initialise a new coo project'
  action: (directory, cmdr) ->
    (new Coo).init directory
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
