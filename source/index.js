'use strict';

exports.handler = function (event, context, callback) {
    require('child_process').exec('cp hello /tmp; cd /tmp; chmod +x hello; /tmp/hello', function(err, data) {
      function responseBody() {
        if (err) return err;
        else return data.toString();
      }
      var response = {
        statusCode: 200, 
        body: "<p>" + responseBody() + "</p>"
      };
      callback(null, response);
    });
};
