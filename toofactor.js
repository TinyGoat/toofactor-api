// Gadget node-router
//
var server = require('./lib/node-router').getServer();

// It rubs the Redis on it's skin
//
var redis = require('./node_modules/redis'),
    client = redis.createClient();
    client.on("error", function (err) {
        console.log("error event - " + client.host + ":" + client.port + " - " + err);
    });

// Generate hex token
//
function tokenize() {
    var output = ""
    var token = 0
    for (i=0; i<=7; i=i+1) {
        token = Math.floor(Math.random()*16).toString(16)
        output = output + " " + token
    }
    return output
}

// Customer?
//
function customer_lookup(match) {
    if (client.get(match)) {
        return tokenize();
   } else {
        return "";
    }
}

// Hey, ho, let's go!
//
server.get("/", function (req, res, match) {
  return ""; 
});

// Pull URI for matching
//
server.get(new RegExp("^/(.*)$"), function hello(req, res, match) {
	return customer_lookup(match);
	 res.end();
});

// Go, go gadget Node
//
server.listen(8080);
