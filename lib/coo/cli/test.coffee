Cli = require '../cli'
Coo = require('../coo').Coo

exports.Test = class Test
  command: 'test [directory]'
  description: 'run the tests'
  action: (directory, cmdr) ->
    (new Coo).test directory
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
