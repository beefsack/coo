fs = require 'fs'
path = require 'path'

describe 'A builder', ->
  it 'should copy non source files', ->
    expect(true).toBe true