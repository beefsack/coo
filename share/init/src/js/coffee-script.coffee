root = if window? then window else exports

root.coffeeAction = ->
  alert 'This code was written in CoffeeScript.'

root.sayHello = {} unless root.sayHello?
root.sayHello.coffee = (name) ->
  "Hello, #{name}"
