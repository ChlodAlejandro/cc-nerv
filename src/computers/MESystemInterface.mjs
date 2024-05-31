import ComputerConnection from "../connection/ComputerConnection.mjs";

export default class MESystemInterface {

    /**
     * @param {number} page
     * @param {`${"alpha"|"order"}-${"asc"|"desc"}`} order
     * @param {number} count
     */
    async list(page, order, count) {
        const meComputer = ComputerConnection.COMPUTER_MAP.get("MESystem");
        if (!meComputer) {
            throw new Error("Computer is down!");
        }

        return meComputer.jobManager.runJob("list", { page, order, count });
    }

    /**
     * @param {number} page
     * @param {`${"alpha"|"order"}-${"asc"|"desc"}`} order
     * @param {number} count
     */
    async listItems(page, order, count) {
        const meComputer = ComputerConnection.COMPUTER_MAP.get("MESystem");
        if (!meComputer) {
            throw new Error("Computer is down!");
        }

        return meComputer.jobManager.runJob("listItems", { page, order, count });
    }

    /**
     * @param {number} page
     * @param {`${"alpha"|"order"}-${"asc"|"desc"}`} order
     * @param {number} count
     */
    async listFluid(page, order, count) {
        const meComputer = ComputerConnection.COMPUTER_MAP.get("MESystem");
        if (!meComputer) {
            throw new Error("Computer is down!");
        }

        return meComputer.jobManager.runJob("listFluid", { page, order, count });
    }

    /**
     * @param {number} page
     * @param {`${"alpha"|"order"}-${"asc"|"desc"}`} order
     * @param {number} count
     */
    async listGas(page, order, count) {
        const meComputer = ComputerConnection.COMPUTER_MAP.get("MESystem");
        if (!meComputer) {
            throw new Error("Computer is down!");
        }

        return meComputer.jobManager.runJob("listGas", { page, order, count });
    }

    async getStatus() {
        const meComputer = ComputerConnection.COMPUTER_MAP.get("MESystem");
        if (!meComputer) {
            throw new Error("Computer is down!");
        }

        return meComputer.jobManager.runJob("getStatus");
    }

}