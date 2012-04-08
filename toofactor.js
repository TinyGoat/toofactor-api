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
    // record_token(output);
    return output
}

// Write generated token for auth purposes
//
function record_token(token) {
    client.set(match, token);
}

// Customer, customer what do you hear..
//
function customer_lookup(match) {
    if (match=="api" ) {
        return tokenize();
   } else {
        return "Incorrect API key.";
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
	response.end();
});

// Go, go gadget Node
//
server.listen(8080);
