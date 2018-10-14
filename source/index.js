'use strict';

exports.handler = function (event, context, callback) {
    require('child_process').execFile('ls', function(err, data) {
      function responseBody() {
        if (err) return "<p>" + err + "</p>";
        else return "<p>" + data.toString() + "</p>";
      }
      var response = {
        statusCode: 200, 
        body: responseBody()
      };
      callback(null, response);
    });
};
