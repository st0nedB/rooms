# rooms
With "Rooms" mobile devices can perform indoor self-localization using an app and low-cost BLE beacons.

Hello,
I'd like to introduce to you a project I have been working on during the last few weeks. Its focus is the localization of mobile devices using low-cost COTS hardware, i.e. the ESP32. By configuring and deploying multiple ESP32's as iBeacon transmitters into a region (e.g. an apartment, house, etc.), a mobile app on the device can detect in which room/area of the region the device currently is. It then uses MQTT to publish the determined region to an MQTT broker. The current room/region is estimated from the RSSI values obtained from all beacons in range.

**Why?**

I started the project because I wanted a BLE solution to detect in which room of my flat my devices are. Among the existing solutions, I found *monitor* and *room-assistant* to be the most promising ones.
One drawback for me was the required hardware. My apartment has six rooms, and equipping each of the rooms with an RPi Zero was not feasible, mainly due to the limited deliverable quantities here in Germany (only 1 per order).

**How?**

I found the ESP32 to be a promising alternative. It has Wifi and BLE build-in, is available for 6-8€, depending on quantity and supplier, and can easily be converted to an iBeacon using *espHome*. Furthermore, I also use it for other sensors (e.g. moisture, light, temperature, etc.). So I still had a bunch of them lying around.
My first idea was to utilize the ESP32's as passive BLE sensors to monitor the advertisements of devices. But, as some may know from the discussions surrounding the current COVID-19 tracing apps,  almost all mobile device manufacturers periodically change the broadcast MAC address, making it hard to identify and track devices. While surely some (maybe complicated) tricks are possible, I didn't want to work around privacy-preserving mechanisms.
Being fully aware of the power consumption drawback of on-device solutions, I still decided to try and see if it works and how large the battery impact truly is.
Regarding the processing, I decided to go with a Machine Learning-based approach. By doing so, overlapping coverage areas of beacons are beneficial instead of harmful. The additional diversity helps to provide more accurate, and stable predictions. Hence beacon positions can be chosen more freely, e.g. near power outlets at convenient locations.
[explanation image]

**Setup procedure**
The initial setup procedures for the system will be as follows:
First, one has to set up the iBeacon identities (UUID, Major ID and, Minor ID) and configure the areas (or rooms, if used for room presence detection). Note, that it is not necessary to provide any map or location of the beacons.
Second, using the App, the wireless propagation characteristics of the iBeacons (currently only the RSSI unfortunately), are collected for each room. This step requires you to move around in the respective rooms while the app performs beacon ranging. Depending on the size of the overall region, this step takes the longest. From my experience, collecting samples in each room for 5-10 minutes should be fine.
Next, the data must be exported from the app to a local computer. Using two simple Python scripts, the data is used to train a model, which is then re-deployed to the app. The model can be deployed to different devices without the need to perform the time-consuming data collection in the second step for each device. 
That's it. The app can now estimate the current room in which the device is. By configuring an MQTT broker and topic of choice, each room change will be pushed to the broker.

**Demo**

Here a short demo GIFs showing the capabilities to control light scenes in combination with some simple Home Assistant automation (room labels are in German ;) ). Many more use cases are possible, e.g. triggering automation if the device is placed on a shelf/table.
The delay is usually in the order of 1-2 seconds.
[demo gif]

**Open Issues**

Of course, there are also some issues. The most important one is the power consumption. Constant beacon ranging in the background will drain the device battery quicker. However, I consider this an open topic for further optimizations. Simple measures can be implemented to counteract. For example, the app will suspend all measurements if the device is not moving or if the device leaves the specified beacon region (e.g. the house).
Additionally, there are many use-cases where non-stop measurements in the background are not required. 
Another issue is instability in the transition between two open areas where no physical separation (e.g. a wall or door) exists. There are techniques to stabilize the predictions in those cases, but implementing them will take further time.

**So, why do this?**

Honestly, I just wanted to know if it works and went from there. Now it is at a point where it fits my use personal use case and works reliably.  Which makes me wonder, whether it will also be useful for others?
Therefore, the next step is to find a small circle of willing testers, who want to try it in their own home and help me improve it.
Currently, the app works only on iOS devices with version 13 and above (I did not test/build for other versions yet).
If you are interested, you will be given access to the app to help me test and develop it further. Once it is confirmed to work for others and the remaining bugs are fixed, I plan to submit it to the Appstore for review and, if all works out, release it for free.

Thanks for sticking with me until here ;)
Looking forward to your replies, feedback, and comments.

**TL;DR** Another way to perform room presence detection based on low-cost BLE beacons for mobile devices using an app and MQTT. Currently iOS only. Interested? Let me know below.

# How to
## Setting up your Beacon environment
It should be possible (not tested yet!) to use all kinds of different Beacon hardware. To use iBeacons with "Rooms" you need to setup your beacons to all use the same UUID and Major value. Give each beacon a unique Minor value to differ between Beacons.
To use ESP32 with iBeacon, I recommend to check out [ESPHome](https://esphome.io). They have a tutorial how to set everything up and configure ESP32 to transmit as iBeacons [here](https://esphome.io/components/esp32_ble_beacon.html?highlight=beacon).

## Setting up the app
On the first launch, the app won't do anything until it is properly configured.
The process to get it running requires the following steps.
1. Setup your beacons
2. Setup your rooms
3. Setup MQTT (optional)
4. Collect training data from each room/area (~ two-three minute per room)
5. Export your data to train the AI specific to your setup (currently done with Python script)
6. Import the AI model back to the app
7. Done :) 
Below all steps are described in more detail.

__1. Setup your iBeacons__
Go to __Settings__ > __Beacons__ and configure your global UUID and Major value. Don't forget to type __Set__ to confirm the values.
Then add all Minor values of your Beacons to the list below.
Swipe down once you are finished.

__2. Setup your Rooms/Areas__
Go to __Settings__ > __Rooms__ and add all your rooms/areas you want your device to detect to the list. 

__3. Setup MQTT__ (optional)
If you want the app to report changes of location to your MQTT broker, you need to configure it. 
Go to __Settings__ > __MQTT__ and configure fill out all required fields. Tap __Set__ to make sure the value is properly configured!
To test the connection, press __Test__ at the very bottom of the display. If everything works out, the red __X__ changes to a checkmark and you should find a short MQTT message on the specified topic.

__4. Collect training data__
Go to __Data__ and choose a room using the _Choose Room from List_ button. You should be able to see all rooms previously configured in step 2. 
Once selected, move your device to the room and press _Start Recording_. The device will then start to collect readings from your beacons.
To get better results, you should move in the room and open/close doors. Also put the device in your pocket and move around (don't just stand still).
__Don't leave the room during this process!__ 
The time required per room depends on whats configured for the _Number of Training Samples per Room_ in the __Settings__ tab. The app will record one sample/second. Larger numbers of training samples _might_ give you better results later, but also take more time to accuire.
Repeat the process for every room.

__5. Export the data and train your own AI__
Once the data is collected for all rooms, you must export the data. The app generates on JSON file for each room with the collected samples.
Pressing the _Export_ button will open the default iOS share dialogue and allow you to export your files.
Export your files to where you can access them with your computer. 
(Add the Traingin part)

__6. Import the AI model back to the app__
To import your model back into the app, you must provide it at a valid URL link. (I know, this seems tedious. Its on the agenda to change it!)
I used NGINX to setup a small server on my local NAS. 
Go to __Settings__ > __Model__ and paste the link to the model there. Press _Set_ and the _Import_. If everything works, the app will import your own model from the URL and compiles it.

__7. Start the prediction__
Finally, go to the initial __Prediction__ tab. Wait for a few seconds to allow the app to compile your model and start collecting readings from your BLE beacons. After a few seconds it should show in which room you are currently in. If you configured MQTT, a new message will be published to the configured topic every time the room changes. 
