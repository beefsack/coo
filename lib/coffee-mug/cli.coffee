# Command classes
Build = require('./cli/build').Build
Watch = require('./cli/watch').Watch

exports.Cli = class Cli
  coffeeMug: null
  commands:
    build: new Build
    watch: new Watch
  factory: (command) ->
    unless @commands[command]?
      throw 'Invalid command, use --help to see a list of commands'
    @commands[command]
  initCommander: (command) ->
    cmdr = require 'commander'
    # Add commands
    for cmdName, cmdInfo of @commands
      cmd = @factory cmdName
      cmd.register cmdr if cmd.register?
    return cmdr if command is '--help' or command is '-h'
    # Let the cli class add custom options if required
    cli = @factory(command)
    cli.initCommander cmdr if cli.initCommander?
    cmdr
  action: (args) ->
    # Get command
    command = args[2]
    unless command?
      throw 'Please specify a command, use --help to see a list of commands'
    args.splice 2, 0
    # Create commander
    cmdr = @initCommander command
    cmdr.parse args
