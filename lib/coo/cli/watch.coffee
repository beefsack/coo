Cli = require '../cli'
Coo = require('../coo').Coo

exports.Watch = class Watch
  command: 'watch [version]'
  description: 'watch for source changes and compile on the fly'
  action: (version, cmdr) ->
    (new Coo).watch version
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
