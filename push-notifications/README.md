## Example Push Notification Daemon for Couchbase Lite

Uses the changes feed from the Sync Gateway to send push notifications to the sync device.

To try example push notification integration, enter your Urban Airship credentials in `config.js`, and [set up your app following the steps in the Urban Airship docs](http://docs.urbanairship.com/build/ios.html#setting-up-urban-airship)

Once you have done that, you will be able to send a push notification to your app from the Urban Airship web console. The node.js script in index.js follows the "push" and "profiles" channels, to send a welcome message to new users, and to message all members of a channel when the channel is updated.

To run it, edit config.js, Then start a Sync Gateway with the configuration in `push-notifications/sync-gateway-config.json`. After that is running on the URL you've listed in config.js, change to the push-notifications directory and run:

	node index.js

This will connect to Couchbase Server (sorry it doesn't work with Walrus storage) to find the latest sequence. It then picks up the push notification feed from there.


