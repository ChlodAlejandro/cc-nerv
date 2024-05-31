import { log } from "../util/log.mjs";

export default function loggerMiddleware(req, _res, next) {
	log(`${req.method} ${req.path} HTTP/${req.httpVersion}`, {
        ip: req.ip,
        query: req.query || undefined
    });
	next();
}