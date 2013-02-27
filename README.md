# CouchChat demo for Couchbase Lite

CouchChat is a multi-user messaging app, essentially a rough clone of the iOS Messages app. It illustrates how you can use Couchbase Lite in your Mobile to share data across devices and among users. If you familiarize yourself with this code, you'll be ready to write your own multi-user interactive data driven applications on iOS.

## Architecture

There are three main components to the system:

* This app, which embeds [Couchbase Lite](https://github.com/couchbase/couchbase-lite-ios) for iOS.
* [Couchbase Server 2.0](http://www.couchbase.com/download) for data storage.
* The Couchbase [Sync Gateway](https://github.com/couchbaselabs/sync_gateway) handles the synchronization connections from mobile devices.

Couchbase Server should be deployed behind your firewall (like databases normally are), and then the Sync Gateway should be deployed where it can be accessed by mobile devices from the public internet, and it can reach Couchbase Server. Mobile devices connect to the Sync Gateway, which enforces access control and update validation policies.

![Couchbase Mobile Architecture](http://jchris.ic.ht/files/slides/mobile-arch.png)

## Building this app

Until we have precompiled binary packages of Couchbase Lite, you will need to build a copy yourself. Once it is built, find the `CouchbaseLite.framework` folder in your build products directory, and drop it into this repository's `Frameworks/` folder (it is listed in `.gitignore` already).

You'll also want to change the `_syncManager.syncURL` variable in `AppDelegate.m` to point to the public hostname and port for your Sync Gateway.

Don't forget to install the libraries we use: UIBubbleTableView and browserid (for Persona support):

    git submodule init
    git submodule update

You are almost ready to hit build and run, but you should configure and launch the Sync Gateway first.

### Configure the Sync Gateway

Installation and configuration of the Sync Gateway is beyond the scope of this README. The [Sync Gateway docs](https://github.com/couchbaselabs/sync_gateway) discuss installation.

Once you have it installed, you'll want to launch it with the `-site` option equal to the URL that your mobile devices will be using to connect to it (from `AppDelegate.m`). It is necessary to pass this information on the command line, so that the Gateway can correctly validate authentication assertions issued by services like [Mozilla Persona](https://login.persona.org/about).

Now that you've got a running Sync Gateway, you need to set the `channelmap` and `validate_doc_update` functions. These are uploaded to the Sync Gateway admin port via an HTTP interface. Don't worry about the details, just run the script that has been included in this CouchChat repository: `./script/push.js`. It requires node.js (version >= 0.8) to run.

(If you get `ECONNRESET` when you run it, restart sync_gateway and try again...)

We'll be patching this script to keep up, as we simplify the Sync Gateway configuration process. If you are trying to run this app and getting obscure errors running `script/push.js` just try updating to the latest from the [`couchbaselabs/`](https://github.com/couchbaselabs/CouchChat-iOS) repo. If that doesn't work, please [contact the mailing list](https://groups.google.com/forum/#!forum/mobile-couchbase)

This script uses the configuration in `script/config.json` to find the Sync Gateway. It turns off GUEST access, and sets up a sync function. The sync function configures how data flows between mobile devices, or can throw an error if a given update is not allowed to proceed. Read the Sync Gateway documentation for more details.

Here is how the sync function for CouchChat works. Notice how the access and channel calls are deployed:

```javascript
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
```

### Launch

Now you can build and run your app in the simulator, and it will prompt you to login with Mozilla Persona. Once you are logged in, you can create chat messages. If you install it on a real phone, you can also take pictures. Any message in a chat room will show up on all devices that are subscribed to that room.




