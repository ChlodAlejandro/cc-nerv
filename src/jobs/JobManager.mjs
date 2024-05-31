import ComputerConnection from "../connection/ComputerConnection.mjs";
import getExternalPromise from "../util/getExternalPromise.mjs";

export default class JobManager {

    /** MESSAGE HANDLERS **/

    /**
     * @param {ComputerConnection} computer 
     * @param {any} data 
     */
    static jobMessageHandler(computer, data) {
        if (computer.jobManager.jobs.has(data.jobId)) {
            const job = computer.jobManager.jobs.get(data.jobId);
            job.res(data);
        }
    }

    /** INSTANCE **/

    constructor(computer) {
        /** @type {ComputerConnection} */
        this.computer = computer;
        /** @type {Map<string, { promise: Promise, res: Function, rej: Function }>} */
        this.jobs = new Map();
    }

    generateJobId() {
        return Math.random().toString(36).substring(2, 15);
    }

    runJob(jobType, data = {}, timeout = 10000) {
        const jobId = this.generateJobId();
        const externalPromise = getExternalPromise();
        this.computer.send("runJob", { jobId, jobType, ...data });
        this.jobs.set(jobId, externalPromise);
        return Promise.race([
            externalPromise.promise
                .then((obj) => {
                    this.jobs.delete(jobId);
                    if (obj.jobId) delete obj.jobId;
                    if (obj.type) delete obj.type;
                    if (obj.jobType) delete obj.jobType;
                    return obj;
                }),
            new Promise((res, rej) => {
                setTimeout(() => {
                    rej("Job timed out");
                    this.jobs.delete(jobId);
                }, timeout);
            })
        ]);
    }

}