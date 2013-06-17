	// Your API key
var API_KEY = "",
	// Your API master key
	MASTER_KEY = "",
	// Your API secret key
	SECRET_KEY = "",
	// 1 to run a broadcast test, 0 to skip
	TEST_BROADCAST = 0,
	// The number of test events to wait for
	EXPECTED_TESTS = 3 + TEST_BROADCAST,
	// The device_token for your test device
	TEST_DEVICE = "",
	UrbanAirship = require("../lib/urban-airship"),
	urban_airship = new UrbanAirship(API_KEY, SECRET_KEY, MASTER_KEY),
	events = require("events"),
	util = require("util");


var Test = function() {
	events.EventEmitter.call(this);
}

util.inherits(Test, events.EventEmitter);

Test.prototype.pushBroadcast = function() {
	var self = this,
		payload = {
			"aps": {
				"alert": "Hello everyone!",
				"badge": 3
			}
		};
	
	urban_airship.pushNotification("/api/push/broadcast/", payload, function(error) {
		self.emit("finished", error, "pushBroadcast")
	});
}

Test.prototype.pushNotification = function() {
	var self = this,
		payload = {
			"device_tokens": [TEST_DEVICE],
			"aps": {
				"alert": "Hello test device!",
				"badge": 3
			}
		};
	
	urban_airship.pushNotification("/api/push/", payload, function(error) {
		self.emit("finished", error, "pushNotification")
	});
}

var test = new Test(),
	failed = 0,
	passed = 0;

test.on("finished", function(error, test_name) {
	if (error) {
		failed += 1;
		console.log("Failed " + test_name + ".");
		error.message && console.log(error.message);
		error.stack && console.log(error.stack);
	}
	else {
		passed += 1;
		console.log("Passed " + test_name + ".");
	}
	
	if (passed + failed === EXPECTED_TESTS) {
		urban_airship.unregisterDevice(TEST_DEVICE, function(error) {
			if (error) {
				failed += 1;
				console.log("Failed unregisterDevice.");
			}
			else { 
				passed += 1; 
				console.log("Passed unregisterDevice.");
			}
			console.log("Completed " + (EXPECTED_TESTS + 1) + " tests (" + passed + " passed, " + failed + " failed).");
			process.exit();
		});
	}
});

test.on("registered", function(error) {
	if (error) {
		error.messge && console.log(error.message);
		error.stack && console.log(error.stack);
		process.exit();
	}
	else {
		passed += 1;
		console.log("Passed registerDevice.");
		
		if (TEST_BROADCAST) {
			test.pushBroadcast();
		}
		
		test.pushNotification();
		
		urban_airship.getDeviceTokenCounts(function(error, total, active) {
			if ((!total && isNaN(total)) || (!active && isNaN(active))) {
				test.emit("finished", new Error("Bogus data: " + total + ", " + active + "."), "getDeviceTokenCounts");
			}
			else {
				test.emit("finished", error, "getDeviceTokenCounts");
			}
		});
	}
});

urban_airship.registerDevice(TEST_DEVICE, function(error) {
	test.emit("registered", error);
});