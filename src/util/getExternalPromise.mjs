export default function getExternalPromise() {
    let res, rej;
    let promise = new Promise((resolve, reject) => {
        res = resolve;
        rej = reject;
    });
    return {
        promise, res, rej
    };
}