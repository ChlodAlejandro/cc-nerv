import BatteryInterface from "../../computers/BatteryInterface.mjs";
import { error, log } from "../../util/log.mjs";

export default async function batteryStatus(req, res) {
    log("Processing battery status check request...");
    
    try {
        if (req.query.units && !["j", "fe"].includes(req.query.units.toLowerCase())) {
            res.status(400);
            res.json({
                error: true,
                message: "Invalid units"
            });
        }
        const status = await new BatteryInterface().getStatus(req.query.units ?? "FE");

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