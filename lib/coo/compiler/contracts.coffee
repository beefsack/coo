contracts = require 'contracts.coffee'

exports.Contracts = class Contracts
  compile: (source) -> contracts.compile source,
    contracts: true
