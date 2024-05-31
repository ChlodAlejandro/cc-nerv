import MESystemInterface from "../../computers/MESystemInterface.mjs";
import { error, log } from "../../util/log.mjs";

export default async function meStatus(req, res) {
    log("Processing status check request...");
    
    try {
        const status = await new MESystemInterface().getStatus();

        if (status.error) {
            res.status(500);
            res.json(status);
            return;
        }
        
        res.json(status);
    } catch (e) {
        error(e);
        res.status(500);
        res.json({
            error: true,
            message: "Failed to get status: " + e.toString()
        });
    }
}