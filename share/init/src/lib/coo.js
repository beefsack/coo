(function() {
  $(document).ready(function() {
    prettyPrint();
  });
  window.sayHello = {
    contracts: function() { alert("Unsupported on your browser"); }
  };
  window.bindSayHello = function(offset, callback) {
    window.sayHello[offset] = callback;
  };
})();
