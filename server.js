const express = require("express");
const http = require("http");
const socketIo = require("socket.io");
const osc = require("osc");

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

app.use(express.static(__dirname));

const udpPort = new osc.UDPPort({
  localAddress: "127.0.0.1",
  localPort: 57121,
  remoteAddress: "127.0.0.1",
  remotePort: 57120
});

udpPort.open();

io.on("connection", (socket) => {
  console.log("Browser connected");

  socket.on("control", (data) => {
    udpPort.send({
      address: "/control",
      args: [
        String(data.name),
        Number(data.value)
      ]
    });
  });

  socket.on("playNote", (data) => {
    console.log("playNote received:", data);

    udpPort.send({
      address: "/playNote",
      args: [
        Number(data.note),
        Number(data.velocity),
        Number(data.amp),
        String(data.instrument)
      ]
    });
  });

  socket.on("stopNote", (data) => {
    udpPort.send({
      address: "/stopNote",
      args: [
        Number(data.note),
        String(data.instrument)
      ]
    });
  });
});

server.listen(3000, () => {
  console.log("Open http://localhost:3000");
});