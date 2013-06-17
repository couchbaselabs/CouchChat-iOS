// this is how we'd use it
var key = process.argv[2]
  , secret = process.argv[3]
  , ua = new require('urban-airship')(key, secret, master)
  // , deviceToken = 'FE66489F304DC75B8D6E8200DFF8A456E8DAEACEC428B427E9518741C92C6660'
  , sg = require("sync-gateway")(require("config"))
  ;

// connect to changes feed for profiles channel
// and send a welcome message

var Run = module.exports = function() {

  sg.channels("profiles", function(doc) {
    var payload = {
      device_tokens : [],
      aliases : [doc.email]
      aps : {
        alert : "welcome to CouchChat, " + (doc.nick || doc.email)
      }
    }
    ua.pushNotification("/api/push", payload, function(err){
      if (err) {
        connect.log("pushNotification err", err)
      }
    })
  })


  sg.channels("push", function(doc) {
    if (doc.channel_id == doc._id) {

    } else {

      sg(doc.channel_id, function(err, channel){
        if (err) {
          console.log('err loading channel', doc.channel_id)
        }
        pushFromChannelDoc(channel, doc)
      })
    }
  });
}

// connect to push feed.
//

function pushFromChannelDoc (channel, doc) {
  var pushTo = [].concat(channel.members).concat(channel.owners)
  async.map(function(to, cb){
    if (to) {
      // lookup device tokens
      // tokens
      console.log()

    } else {
      cb()
    }
  }, function(err, tokens) {
    // var payload = {
    //   device_tokens : [],
    //   aps : {
    //     alert : "welcome to CouchChat, " + doc.
    // "new message from"+doc.author
    //   }
    // }
  });
  pushTo.forEach()
}

