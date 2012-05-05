fs = require 'fs'

# Load the config file
configFile = 'config.json'
configFileContents = fs.readFileSync configFile, 'utf8'
config = JSON.parse configFileContents

# Define filename variables
buildFiles =
  concatenated: "build/#{config.buildName}-concat.js"
  minified: "build/#{config.buildName}-min.js"

desc 'Build the source.'
task 'make', [buildFiles.minified]

desc 'Compile from source.'
task 'compile', ['build', 'build/compiled'], ->
  console.log 'Compiling source...'
  jake.exec ['coffee -o build/compiled/ -c src/'], ->
    console.log 'Successfully compiled source.'
    complete()
, {async: true}


desc 'Clean build directory.'
task 'clean', ->
  console.log 'Cleaning build directory...'
  jake.exec ['rm -rfv build'], ->
    console.log 'Successfully cleaned build directory.'
    complete()
, {async: true}

directory 'src'
directory 'build'
directory 'build/compiled'
file buildFiles.concatenated, ['compile'], ->
  jake.Task['compile'].invoke()
  console.log 'Concatenating compiled source...'
  jake.exec ["find build/compiled/ -name *.js | xargs cat > #{buildFiles.concatenated}"], ->
    console.log 'Successfully concatenated compiled source.'
    complete()
, {async: true}  
file buildFiles.minified, [buildFiles.concatenated], ->
  console.log 'Minifying source...'
  jake.exec ["uglifyjs #{buildFiles.concatenated} > #{buildFiles.minified}"], ->
    console.log 'Successfully minified source.'
    complete()
, {async: true}
