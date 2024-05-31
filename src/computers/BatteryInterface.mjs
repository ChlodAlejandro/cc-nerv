import ComputerConnection from "../connection/ComputerConnection.mjs";

export default class BatteryInterface {

    async getStatus(units) {
        const batComputer = ComputerConnection.COMPUTER_MAP.get("Battery");
        if (!batComputer) {
            throw new Error("Computer is down!");
        }

        return batComputer.jobManager.runJob("getStatus", { units })
            .then((result) => {
                result.lastNet = (result.lastInput ?? 0) - (result.lastOutput ?? 0);
                if (result.avgOutput == null && result.avgInput == null) {
                    result.avgNet = null;
                } else {
                    result.avgNet = (result.avgInput ?? 0) - (result.avgOutput ?? 0);
                }

                const tickRate = 20;

                let lastNetPerSecond = result.lastNet * tickRate;
                let avgNetPerSecond = result.avgNet * tickRate;
                let lastLossPerSecond = result.lastOutput * tickRate;
                let avgLossPerSecond = result.avgOutput * tickRate;
                result.timeToEmpty = {
                    last: lastNetPerSecond >= 0 ? null : result.energy / Math.abs(lastNetPerSecond),
                    avg: avgNetPerSecond >= 0 ? null : result.energy / Math.abs(avgNetPerSecond),
                    worst: result.energy / avgLossPerSecond,
                    lastWorst: result.energy / lastLossPerSecond
                };
                if (result.timeToEmpty.worst === Infinity || isNaN(result.timeToEmpty.worst)) {
                    result.timeToEmpty.worst = null;
                }
                if (result.timeToEmpty.lastWorst === Infinity || isNaN(result.timeToEmpty.lastWorst)) {
                    result.timeToEmpty.lastWorst = null;
                }
                result.emptyTime = {
                    last: result.timeToEmpty.last != null
                        ? new Date(Date.now() + result.timeToEmpty.last * 1000).toISOString()
                        : null,
                    avg: result.timeToEmpty.avg != null
                        ? new Date(Date.now() + result.timeToEmpty.avg * 1000).toISOString()
                        : null,
                    worst: result.timeToEmpty.worst != null
                        ? new Date(Date.now() + result.timeToEmpty.worst * 1000).toISOString()
                        : null,
                    lastWorst: result.timeToEmpty.lastWorst != null
                        ? new Date(Date.now() + result.timeToEmpty.lastWorst * 1000).toISOString()
                        : null
                };

                return result;
            });
    }

    async flushSamples() {
        const batComputer = ComputerConnection.COMPUTER_MAP.get("Battery");
        if (!batComputer) {
            throw new Error("Computer is down!");
        }

        return batComputer.jobManager.runJob("flushSamples")
            .then((v) => !!v?.ok ? true : v);
    }

}