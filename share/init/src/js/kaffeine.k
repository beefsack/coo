(function() {
  @kaffeineAction = function() {
    alert('This was written in Kaffeine!');
  }

  window.sayHello.kaffeine = function(n = 'Kaffeine') {
    return "Hello, #{n}";
  }
}).call(this);
