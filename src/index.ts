import * as express from 'express';
import * as http from 'http';
import * as WebSocket from 'ws';
import * as path from 'path';
import { stats } from './stats';

const app = express();
app.use(express.static(path.join(__dirname, '..', 'static')))

const server = http.createServer(app);

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws: WebSocket) => {
  ws.on('message', (data:string) => {
    try {
      targetCpuRatio = Math.min(JSON.parse(data).targetCpuRatio || 0, 1)
    } catch(err) {
      console.error(err)
      targetCpuRatio = 0
    }
  })
  ws.on('close', () => {
    ws.removeAllListeners()
  })
});

const REFRESH_INTERVAL = 1000
let targetCpuRatio = 0

const useRatioCpu = (ratio:number) => {
  const start = Date.now();
  while ((Date.now() - start) < Math.min(REFRESH_INTERVAL * ratio, REFRESH_INTERVAL));
}

setInterval(() => {
  useRatioCpu(targetCpuRatio)

  const statsString = JSON.stringify({...stats(), targetCpuRatio})
  console.log(`Client count:${wss.clients.size}, stats:${statsString}`)

  wss.clients.forEach(function each(client) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(statsString);
    }
  })
}, REFRESH_INTERVAL)

server.listen(process.env.PORT || 3000, () => {
    console.log(`Server started ${JSON.stringify(server.address())}`);
});