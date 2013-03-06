#!/usr/bin/env node

var config = require("./config"),
  wrangler = require("sync-wrangler");

config.sync = function(doc, oldDoc, userCtx, secObj) {
  if (doc.channel_id) {
    // doc belongs to a channel
    channel("ch-"+doc.channel_id);
    // this document describes a channel
    if (doc.channel_id == doc._id) {
      // magic document, treat it carefully
      if (oldDoc && oldDoc.owners.indexOf(userCtx.name) == -1) {
        throw({unauthorized:"you are not a channel owner"});
      }
      // grants access to the channel to all members and owners
      access(doc.owners, "ch-"+doc._id);
      access(doc.members, "ch-"+doc._id);
    }
  }
  if (doc.type == "profile") {
    channel("profiles");
    var user = doc._id.substring(doc._id.indexOf(":")+1);
    access(user, "profiles");
  }
}

.toString()


wrangler.setup(config, function(err){
  if (err) {return console.log("error"+ err)}
  console.log("gateway configured")
});


