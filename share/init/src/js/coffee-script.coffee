this.coffeeAction = ->
  alert 'This code was written in CoffeeScript.'

window.sayHello = {} unless window.sayHello?
window.sayHello.coffeeScript = ->
  sayHello = (name) ->
    alert "Hello, #{name}"
  sayHello 'CoffeeScript'