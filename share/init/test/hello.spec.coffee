require '../src/js/coffee-script'

describe 'A hello sayer', ->
  it 'should say hello', ->
    expect(window.sayHello.coffee('Guy')).toMatch(/^hello/i)
