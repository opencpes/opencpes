cordova.define("com.opencpes.blackhat.demo.plugin.BlackHatDemoPlugin", function(require, exports, module) {
var exec = require('cordova/exec');

exports.start = function(success, error) {
  exec(success, error, "BlackHatDemoPlugin", "start", []);
};

exports.getCredits = function() {
  return new Promise(function(resolve, reject) {
    exec(resolve, reject, "BlackHatDemoPlugin", "getCredits", []);
  });
};

exports.submitCredit = function(obj) {
  var credit = JSON.stringify(obj);
  return new Promise(function(resolve, reject) {
    exec(resolve, reject, "BlackHatDemoPlugin", "submitCredit", [credit]);
  });
}

});
