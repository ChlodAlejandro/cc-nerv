import ComputerConnection from "../connection/ComputerConnection.mjs";

export default function computers(req, res) {
    res.json({
        computers: Array.from(ComputerConnection.COMPUTER_MAP.keys())
    });
}