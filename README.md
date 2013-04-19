# CouchChat demo for Couchbase Lite

CouchChat is a multi-user messaging app, essentially a primitive clone of the iOS Messages app. It illustrates how you can use Couchbase Lite in your mobile apps to share data across devices and among users. If you familiarize yourself with this code, you'll be ready to write your own multi-user interactive data driven applications on iOS.

## Architecture

There are three main components to the system:

* This app, which embeds [Couchbase Lite](https://github.com/couchbase/couchbase-lite-ios) for iOS.
* The Couchbase [Sync Gateway](https://github.com/couchbaselabs/sync_gateway), which runs on a server and handles the synchronization connections from mobile devices.
* [Couchbase Server 2.0](http://www.couchbase.com/download) for data storage. (For development this is optional; you can instead use a very simple built-in data store called Walrus.)

Couchbase Server should be deployed behind your firewall (like databases normally are), and then the Sync Gateway should be deployed where it can be accessed by mobile devices from the public internet, and it can reach Couchbase Server. Mobile devices connect to the Sync Gateway, which enforces access control and update validation policies.

![Couchbase Mobile Architecture](http://jchris.ic.ht/files/slides/mobile-arch.png)

## Running this app

Until we have precompiled binary packages of Couchbase Lite, you will need to build a copy yourself. Once it is built, find the `CouchbaseLite.framework` folder in your build products directory, and drop it into this repository's `Frameworks/` folder (it is listed in `.gitignore` already).

Don't forget to install the submodules we use: UIBubbleTableView and browserid (for Persona support):

    git submodule init
    git submodule update

Now can build and run your app in the simulator or on a connected iOS device, and it will prompt you to login with Mozilla Persona. Once you are logged in, you can create a chat room, invite other uers, and send messages. You can attach pictures to a message (or take a picture if your device has a camera.) Any message in a chat room will show up on all devices that are subscribed to that room.

For extra credit you can try running the HTML5 version of CouchChat against the same Sync Gateway database. The HTML5 version of the app is under development in our [Couchbase Lite PhoneGap Kit](https://github.com/couchbaselabs/Couchbase-Lite-PhoneGap-Kit) repository.

## Running your own server

If you want to run your own chat server rather than the default public one, you'll need to install the Couchbase Sync Gateway, configure it for chat, and update the iOS app to talk to it.

### Install the Sync Gateway

Installation and configuration of the Sync Gateway is beyond the scope of this README. The [Sync Gateway docs](https://github.com/couchbaselabs/sync_gateway) discuss installation. When you're done you'll be the proud owner of a `sync_gateway` command-line tool.

### Configure the gateway for chat

The CouchChat repo contains a configuration file for the gateway, `sync-gateway-config.json`. Put the path to the config file on the command line when you launch the gateway.

This config file does not contain the public (or LAN) address that your iOS app will contact. The Gateway needs to be aware of that address in order for Persona authentication to work properly. You'll provide that address as a command line option. It should consist only of the root URL of the server, including the port but without any path or trailing slash.

So your launch command will look something like:

    sync_gateway -personaOrigin="http://animal.local:4984" ~/code/CouchChat-iOS/sync-gateway-config.json

The example config file uses an in-memory Walrus bucket, so all your data will be lost when the Sync Gateway exits. To avoid this you can edit the `databases.sync_gateway.server` property of the config file to point to an existing directory where you'd like to store your data. In production you should replace the `walrus:` url with a URL to Couchbase Server's 8091 port.

### Update the iOS app

Now edit the value of `kServerDBURLString` in `AppDelegate.m` to the public URL of your Sync Gateway's chat database. This should match the value of the `-personaOrigin` command-line flag given to the Sync Gateway, but with the database name (default is `chat`) appended.

## How the data flows

The JavaScript sync function in the server config file (`sync-gateway-config.json`) determines how data flows between mobile devices, or it can throw an error if a given update is not allowed to proceed. Read the Sync Gateway documentation for more details.

Here is how the sync function for CouchChat works. Notice how the access and channel calls are deployed:

```javascript
function(doc, oldDoc, userCtx, secObj) {
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
```
