# Gets an equivalent js file name for a coffee file name, handling both .coffee
# and .js.coffee.
exports.getJsName = (file) ->
  return file.replace /(\.js)?\.coffee$/, '.js' if file.match /\.coffee$/
  file

# Used to track the watcher timeout, to avoid build spam on mass source changes.
exports.watchTimeout = null
exports.watchTimeoutWaiting = false
