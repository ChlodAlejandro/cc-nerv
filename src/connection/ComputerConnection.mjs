import config from "../config.mjs";
import buildMsg from "../data/buildMsg.mjs";
import JobManager from "../jobs/JobManager.mjs";
import { log, warn } from "../util/log.mjs";

export default class ComputerConnection {

    /** MESSAGE HANDLERS **/

    /** @type {Map<string, ComputerConnection>} */
    static COMPUTER_MAP = new Map();
    
    /**
     * @param {ComputerConnection} computer 
     * @param {any} data 
     * @returns 
     */
    static onHandshakeMessage(computer, data) {
        log(data);
        if (!config.ws.knownLabels.includes(data.computerLabel)) {
            warn("Bad label. Disconnecting.");
            computer.disconnectError("Bad label");
            return;
        }
        
        if (ComputerConnection.COMPUTER_MAP.has(data.computerLabel)) {
            warn("Computer is reconnecting?!");
            warn("Previous connection may have been lost.");
            warn("Accepting connection.");
        } else {
            log("Successful handshake.");
        }
        computer.authenticate(data);
        computer.send("handshakeOK");
    }

    /** INSTANCE **/

    /**
     * @param {WebSocket} ws
     * @param {import('express').Request} req
     */
    constructor(ws, req) {
        /** @type {string} */
        this.ip = req.ip;
        /** @type {WebSocket} */
        this.ws = ws;
        this.authenticated = false;

        this.jobManager = new JobManager(this);

        this.ws.on("pong", () => { this.isAlive = true; });
        this.pingInterval = setInterval(() => {
            if (this.isAlive === false)
                this.ws.terminate();

            this.isAlive = false;
            this.ws.ping();
        }, 15e3);
        this.ws.ping();
    }

    /**
     * Disconnecting from the server side? Don't call this directly!
     * Use `disconnect` for a graceful disconnect.
     */
    close() {
        clearInterval(this.pingInterval);
        this.ws.close();
        if (this.meta && this.meta.computerLabel)
            ComputerConnection.COMPUTER_MAP.delete(this.meta.computerLabel);
    }

    disconnect(message) {
        this.ws.send(buildMsg("disconnect", { message }));
        this.close();
    }

    disconnectError(message) {
        this.ws.send(buildMsg("error", { message }));
        this.close();
    }

    send(type, data) {
        log(type, data);
        this.ws.send(buildMsg(type, data));
    }

    authenticate(meta) {
        this.authenticated = true;
        this.meta = {};
        if (meta.computerId)
            this.meta.computerId = meta.computerId;
        if (meta.computerLabel)
            this.meta.computerLabel = meta.computerLabel;
        ComputerConnection.COMPUTER_MAP.set(meta.computerLabel, this);
    }

}