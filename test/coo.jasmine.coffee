fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
util = require 'util'
Coo = require('../lib/coo/coo').Coo

fixturesDir = path.join __dirname, '../share/test/fixtures'
testDir = path.join __dirname, '../tmp/test'

initCoo = (fixture = "base") ->
  # Make a Coo
  coo = new Coo
  coo.dir = testDir
  # Clear test dir
  wrench.rmdirSyncRecursive testDir, true
  # Copy src to test dir for fixture
  wrench.mkdirSyncRecursive testDir
  wrench.copyDirSyncRecursive path.join(fixturesDir, fixture), testDir
  coo

describe 'A builder', ->
  it 'should copy non source files', ->
    builder = initCoo().builder()
    builder.build()
    sourcePath = builder.sourcePath
    compilePath = builder.getCompilePath 'development'
    outputPath = builder.getOutputPath 'development'
    nonSourceFile = 'js/something.notsource'
    # Check it exists
    expect(path.existsSync(path.join(outputPath, nonSourceFile))).toBe true
    # Check contents are the same
    expect(builder.getFileHash(path.join(outputPath, nonSourceFile))).
      toBe builder.getFileHash(path.join(sourcePath, nonSourceFile))