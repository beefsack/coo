Cli = require '../cli'
CoffeeMug = require('../coffee-mug').CoffeeMug

exports.Server = class Server
  command: 'server [version]'
  description: 'run a web server while watching the source for updates'
  action: (version, cmdr) ->
    (new CoffeeMug).server version
  register: (cmdr) ->
    cmd = cmdr.command @command
    cmd.description @description
    cmd.action @action
