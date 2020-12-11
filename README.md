
This nodeJS application is a simple webserver to support portchain's coding challenge for the role of Devops.

![User interface of the web application](./README_screengrab.gif "Recording of the web app UI")



Architecture
===

The web server is a single process nodeJS application that exposes a HTTP and websocket endpoint.
The web interface provides a real time view into the node process by exposing its memory and CPU 
usage as well as its uptime.

- A nodeJS application (Tested with NodeJS version 12 and 14)
- Listens to port `3000` by default but can be configured through the `PORT` environment variable
- Single process, no need to run multiple nodes


Key data points
===

- The webserver serves 2 protocols on the same port: HTTP and WebSocket.
- The port used by the webserver is `3000` by default but that can be changed with the `PORT` environment variable.
- The application logs the number of clients that are connected and the data points displayed in the UI.
