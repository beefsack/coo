contracts = require 'contracts.coffee'
console.log contracts

exports.Contracts = class Contracts
  compile: (source) -> contracts.compile source,
    contracts: true
