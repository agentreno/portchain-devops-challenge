


function connect(onNewSocket, onData) {

  let wsUrl;
  if (window.location.protocol === "https:") {
    wsUrl = "wss:";
  } else {
    wsUrl = "ws:";
  }
  wsUrl += "//" + window.location.host;
  wsUrl += window.location.pathname;
  
  // Create WebSocket connection. 
  
  let backOff = 100
  
  console.log('Connecting to server...')
  const socket = new WebSocket(wsUrl);
  onNewSocket(socket);

  // Connection opened
  socket.addEventListener('open', function (event) {
    backOff = 100
    console.log('Connected to server')
  });

  socket.addEventListener('close', function (event) {
    console.log(`Disconnected from server. Will retry the connection in ${backOff}ms`)
    setTimeout(function() {
      backOff = Math.min(backOff*2, 5000)
      connect(onNewSocket, onData)
    }, backOff)
  });

  socket.addEventListener('error', function (event) {
      socket.close()
  });

  // Listen for messages
  socket.addEventListener('message', function (event) {
    const data = JSON.parse(event.data)
    onData(data)
  });
}