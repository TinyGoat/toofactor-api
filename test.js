// Hey, ho, let's go
//
var server = require('./lib/node-router').getServer();
var redis = require("./node_modules/redis-node");
var client = redis.createClient();

// Generate hex token
//
function customer_lookup(match) {
    return "";
}

// We don't serve anything via root
//
server.get("/", function (req, res, match) {
  return ""; 
});

// Stage API access for future proofing
//
server.get(new RegExp("^/(.*)$"), function hello(req, res, match) {
    return client.get('api/');
});

// Go, go gadget Node
//
server.listen(8080);
