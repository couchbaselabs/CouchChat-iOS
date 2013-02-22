#!/usr/bin/env node

var config = require("./config"),
  wrangler = require("sync-wrangler");

config.channelmap =

function(doc) {
  if (doc.channel_id) {
    sync("ch-"+doc.channel_id);
  }
  if (doc.channel_id == doc._id) {
    // grant access to the channel to all
    // members and owners
    sync("ch-"+doc._id);
    access(doc.owners, "ch-"+doc._id);
    access(doc.members, "ch-"+doc._id);
  }
}

.toString()

config.validate_doc_update = function (newDoc, oldDoc, userCtx) {
  if (newDoc._deleted === true && userCtx.roles.indexOf('_admin') === -1) {
    throw "Only admin can delete documents on this database.";
  }
}.toString()

wrangler.setup(config, function(err){
  if (err) {return console.log("error"+ err)}
  console.log("gateway configured")
});


