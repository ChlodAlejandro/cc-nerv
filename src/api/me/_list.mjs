import MESystemInterface from "../../computers/MESystemInterface.mjs";
import { error, log } from "../../util/log.mjs";

export async function _meList(type = "all", req, res) {
    log("Processing list request...");
    
    console.log(type);
	if (!["all", "items", "fluid", "gas"].includes(type)) {
        res.status(400);
        res.json({
            error: true,
            message: "Invalid type: " + type
        });
    }
	const page = req.query["page"] ?? 0;
	const order = req.query["order"] ?? "count-desc";
	const count = req.query["count"] ?? 50;
	
    try {
        const list = await new MESystemInterface()[
            {
                all: "list",
                items: "listItems",
                fluid: "listFluid",
                gas: "listGas"
            }[type]
        ](page, order, count);

        if (list.error) {
            res.status(500);
            res.json(list);
            return;
        }
        
        res.json(list);
    } catch (e) {
        error(e);
        res.status(500);
        res.json({
            error: true,
            message: "Failed to get list: " + e.toString()
        });
    }
}