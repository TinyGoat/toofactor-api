// api.js - spit out auth token

// We likes Redis
//
var redis = require("redis"),
client = redis.createClient();
client.on("error", function (err) {
    console.log("Error " + err);
});

// Here for reference
//
var our_salt = "40402eb3b359d4ac27tG4AF4";

// Customer records are stored in Redis:
// <sha256 of email + salt> :: email_address
//

function customer_lookup(match) {
    if (client.exists(match)) {
        var output = ""
        for (i=0; i<=5; i=i+1) {
            var rnd = Math.floor(Math.random()*10);
            rnd = rnd+'';
            var output = output + rnd;
        }
        
        return output;
    }
}
