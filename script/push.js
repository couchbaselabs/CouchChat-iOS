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
}

.toString()

config.validate_doc_update = function (newDoc, oldDoc, userCtx) {
  var doc = newDoc;
  if (doc.channel_id && doc.channel_id == doc._id) {
    // magic document, treat it carefully
    // grants access to the channel to all members and owners
    if (doc.owners.indexOf(userCtx.name) == -1) {
      throw({unauthorized:"you are not a channel owner"});
    }
  }

  if (newDoc._deleted === true && userCtx.roles.indexOf('_admin') === -1) {
    throw "Only admin can delete documents on this database.";
  }
}.toString()

wrangler.setup(config, function(err){
  if (err) {return console.log("error"+ err)}
  console.log("gateway configured")
});


