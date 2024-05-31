import config from "../config.mjs";
import ComputerConnection from "./ComputerConnection.mjs";
import handlers from "./handlers.mjs";
import { log, warn, error } from "../util/log.mjs";
import buildMsg from "../data/buildMsg.mjs";

export function onWebsocketMessage(computer, message) {
    log(`Receiving message from ${computer.ip}...`);

    let data;
    try {
        data = JSON.parse(message);
    } catch (e) {
        error("Bad parse on message!");
        error(message);
        error("Disconnecting for safety.");
        computer.ws.close();
        return;
    }
    
    log(`:: type: ${data.type}`);
    if (!computer.authenticated && data.type !== "handshake") {
        warn("Expected a handshake message. Disconnecting.");
        computer.disconnectError("No handshake message");
        return;
    }

    let handler;
    if (typeof handlers === "object" && handlers[data.type]) {
        handler = handlers[data.type];
    }
    if (typeof computer.handlers === "object" && computer.handlers[data.type]) {
        handler = computer.handlers[data.type];
    }

    if (!handler) {
        error("No handler for message type! Disconnecting for safety.");
        computer.disconnectError("Message type unrecognized");
        return;
    }

    if (data.type != "pong")
        log(`Passing to handler (${handler.name})...`);
    handler(computer, data);
}

export function onWebsocketConnect(ws, req) {
    if (!config.ws.allowedIPs.includes(req.ip.toLowerCase())) {
        warn("Not authorized! Kicking...");
        ws.send(buildMsg("error", { message: "Bad IP" }));
        ws.close();
        return;
    }

    const computer = new ComputerConnection(ws, req);
    ws.on("message", onWebsocketMessage.bind(null, computer));
    ws.on("close", function () {
        log(`Closed websocket connection from ${req.ip}.`);
        computer.disconnect();
    });
}