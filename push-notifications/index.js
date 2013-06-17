var config = require("./config")
  , UAp  = require('urban-airship')
  , ua = new UAp(config.UAirship.key, config.UAirship.secret, config.UAirship.master)
  , sw = require("sync-wrangler")(config.gateway.url)
  , async = require("async")
  , couchbase = require("couchbase")
  ;

// connect to changes feed for profiles channel
// and send a welcome message

// console.log("ua",ua, UAp)


couchbase.connect({
  "bucket" : "chat"
}, function(err, bucket) {
  if (err) throw (err)
  // console.log("bucket", bucket)
  bucket.get("_push:seq", function(err, push_seq) {
    if (err) {
      push_seq = "";
    }
    console.log("push_seq", push_seq)



    function pushFromChannelDoc (users, message, seq) {
      var aliases = []
      for (var i = users.length - 1; i >= 0; i--) {
        if (users[i]) {
          aliases.push(users[i])
        }
      };

      var payload = {
        aliases : aliases,
        aps : {
          alert : message
        }
      }
      ua.pushNotification("/api/push", payload, function(error) {
        console.log("pushed to", aliases)
        if (seq) {
          bucket.set("_push:seq", seq, function(err, ok){
            console.log("saved push seq",seq, err, ok)
          });
        }
      });

    }


    var push = sw.channels(["profiles","push"], {since : push_seq})
    // push.on("json", function(json){

    // })
    push.on("doc", function(doc, change) {
      if (doc.email) {
        var payload = {
          device_tokens : [],
          aliases : [doc.email],
          aps : {
            alert : "Welcome to CouchChat, " + (doc.nick || doc.email)+"."
          }
        }
        ua.pushNotification("/api/push", payload, function(err){
          if (err) {
            console.log("pushNotification err", err, payload )
          } else {
            console.log("pushed", payload)
            if (change.seq) {
              bucket.set("_push:seq", change.seq, function(err, ok){
                console.log("saved push seq",change.seq, err, ok)
              });
            }
          }
        })
      } else if (doc.channel_id && doc.author) {
        sw(doc.channel_id, function(err, channel){
          pushFromChannelDoc([].concat(channel.members).concat(channel.owners), doc.author+": "+(doc.markdown || "Photo"), change.seq)
        })
      }
    })
  })

})




