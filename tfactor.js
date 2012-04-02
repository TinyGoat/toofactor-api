// Hey, ho, let's go
//
var server = require('./lib/node-router').getServer();

// We don't serve anything via root
//
server.get("/", function (req, res, match) {
  return ""; 
});

// Stage API access for future proofing
//
server.get(new RegExp("^/api/v1/(.*)$"), function hello(req, res, match) {
  return "Hello " + (match || "World") + "!";
});


// Go, go gadget Node
//
server.listen(8080);
