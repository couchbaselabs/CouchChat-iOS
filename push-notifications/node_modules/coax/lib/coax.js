/*
 * coax
 * https://github.com/jchris/coax
 *
 * Copyright (c) 2013 Chris Anderson
 * Licensed under the Apache license.
 */
var pax = require("pax"),
  hoax = require("hoax");

var coaxPax = pax();

coaxPax.extend("getQuery", function(params) {
  params = JSON.parse(JSON.stringify(params));
  var key, keys = ["key", "startkey", "endkey", "start_key", "end_key"];
  for (var i = 0; i < keys.length; i++) {
    key = keys[i];
    if (params[key]) {
      params[key] = JSON.stringify(params[key]);
    }
  }
  return params;
});

var Coax = module.exports = hoax.makeHoax(coaxPax());

Coax.extend("changes", function(opts, cb) {
  if (typeof opts === "function") {
    cb = opts;
    opts = {};
  }
  var self = this;
  opts = opts || {};

  if (opts.feed == "continuous") {
    var listener = self(["_changes", opts], function(err, ok) {
      if (err && err.code == "ETIMEDOUT") {
        return self.changes(opts, cb); // TODO retry limit?
      } else if (err) {
        return cb(err);
      }
    });
    listener.on("data", function(data){
      var json = JSON.parse(data);
      cb(false, json)
      // console.log("data", data.toString())
    })
    return listener;
  } else {
    opts.feed = "longpoll";
    // opts.since = opts.since || 0;
    // console.log("change opts "+JSON.stringify(opts));
    return self(["_changes", opts], function(err, ok) {
      if (err && err.code == "ETIMEDOUT") {
        return self.changes(opts, cb); // TODO retry limit?
      } else if (err) {
        return cb(err);
      }
      // console.log("changes", ok)
      ok.results.forEach(function(row){
        cb(null, row);
      });
      opts.since = ok.last_seq;
      self.changes(opts, cb);
    });
  }
});

Coax.extend("forceSave", function(doc, cb) {
  var api = this(doc._id);
  // console.log("forceSave "+api.pax);
  api.get(function(err, old) {
    if (err && err.error !== "not_found") {
      return cb(err);
    }
    if (!err) {
      doc._rev = old._rev;
    }
    api.put(doc, cb);
  });
});
