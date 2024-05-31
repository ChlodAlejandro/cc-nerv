import JobManager from "../jobs/JobManager.mjs";
import ComputerConnection from "./ComputerConnection.mjs";

export default {
    handshake: ComputerConnection.onHandshakeMessage,
    finishJob: JobManager.jobMessageHandler,
    pong: function () {}
};