function getLogDate() {
    return new Date().toLocaleString("en-US", { dateStyle: "medium", timeStyle: "long" });
}

export function log(...args) {
    console.log(`[${getLogDate()}]`, ...args);
}

export function error(...args) {
    console.error(`[${getLogDate()}]`, ...args);
}

export function warn(...args) {
    console.warn(`[${getLogDate()}]`, ...args);
}