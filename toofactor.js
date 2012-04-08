// Hey, ho, let's go
//
require('util');
var server = require('./lib/node-router').getServer();
var redis = require('./node_modules/redis'),
    client = redis.createClient();
    client.on("error", function (err) {
        console.log("error event - " + client.host + ":" + client.port + " - " + err);
    });

// Generate hex token
//
function customer_lookup(match) {
    if (client.get(match)) {
        var output = ""
        var token = 0
        for (i=0; i<=7; i=i+1) {
            token = Math.floor(Math.random()*16).toString(16)
            output = output + " " + token
        }
        return output
    } else {
        return "";
    }
}

// We don't serve anything via root
//
server.get("/", function (req, res, match) {
  return ""; 
});

// Stage API access for future proofing
//
server.get(new RegExp("^/(.*)$"), function hello(req, res, match) {
	return customer_lookup(match);
});

// Go, go gadget Node
//
server.listen(8080);
