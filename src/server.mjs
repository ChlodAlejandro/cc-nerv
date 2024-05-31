import express from 'express';
import expressWs from 'express-ws';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { log, error, warn } from './util/log.mjs';
import { onWebsocketConnect } from './connection/hooks.mjs';
import loggerMiddleware from './middleware/logger.mjs';
import config from './config.mjs';

(async function () {
	const app = express();

	log("Starting...");

	log(`Accepting connections from: [${config.ws.allowedIPs.join(", ")}]`);
	log(`Accepting computers named: [${config.ws.knownLabels.join(", ")}]`);

	// Middleware
	app.set('trust proxy', ['loopback', 'linklocal', 'uniquelocal']);
	app.use(loggerMiddleware);

	// Websockets
	expressWs(app);
	app.ws("/ws", function (ws, req) {
		log(`Received websocket connection from ${req.ip}`);
		onWebsocketConnect(ws, req);
	});

	// API
	async function api(path) {
		path = path.replace(/^\//, '');
		app.get(`/api/${path}`, await import(
			"file:///" + resolve(
				dirname(fileURLToPath(import.meta.url)),
				`api/${path}.mjs`
		)).then(m => m.default));
	}
	api("/computers");
	api("/me/list");
	api("/me/listItems");
	api("/me/listFluid");
	api("/me/listGas");
	api("/me/status");
	api("/battery/status");

	// Static
	app.use("/lua", express.static("lua"));
	app.use(express.static("public", { extensions: [ 'html' ] }));

	// Legacy redirects
	app.get("/list", function (_, res) {
		res.redirect(301, "/me/list");
	});

	app.listen(process.env.PORT || 8080, (e) => {
		if (e) {
			error("Failed to open.", e);
		} else {
			log("Listening!");
		}
	});
})();