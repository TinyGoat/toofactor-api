var server = require('./lib/node-router').getServer();

server.get("/", function (req, res, match) {
  return "Hi"; 
});

server.get(new RegExp("^/1/(.*)$"), function hello(req, res, match) {
  return "Hello " + (match || "World") + "!";
});


server.listen(8080);
