cs = require '../src/js/coffee-script'

describe 'A hello sayer', ->
  it 'should say hello', ->
    expect(cs.sayHello.coffee('Guy')).toMatch(/^hello/i)
