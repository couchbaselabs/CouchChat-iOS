#node-urban-airship

Simple wrapper for the Urban Airship API.

How to use:

npm install urban-airship

Reference the module: require("urban-airship") 

Authenticate with Urban Airship.

	ua = new UA("<api key>", "<api secret key>", "<api master key>");

Use Node-Urban-Airship.

Sample API Calls

1. Register a device

	ua.registerDevice("< token >", function(error) {...});

2. Create payloads for the push notification API needed.

	Information available here.
	http://urbanairship.com/docs/push.html

	Push Notification Examples: 

		a)	"/api/push/"

		var payload0 = {
			"device_tokens": [
			The device or device ids to send the message to
			],
			"aps": {
				"alert": "Calling Urban Airship!",
				"badge": 2
			}
		};

		ua.pushNotification("/api/push", payload0, function(error) {....});

		b) "/api/push/broadcast/"

		var payload1 = {
			"aps": {
				 "badge": 15,
				 "alert": "Calling Urban Airship!",
				 "sound": "cat.caf"
			},
			"exclude_tokens": [
				"device token you want to skip",
				"another device token you want to skip"
			]
		};

		ua.pushNotification("/api/push/broadcast/", payload1, function(error) {.....});

3. Unregister a device.

	ua.unregisterDevice("< token >", function(error) {....});



