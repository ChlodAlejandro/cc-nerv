import 'dotenv/config';

export default {
    ws: {
        // IPs permitted for websocket connections
        allowedIPs: [
            ...(function() {
                const customIPs = (process.env.NERV_IPS ?? "")
                    .split(",")
                    .map(v => v.trim().toLowerCase());
                if (customIPs.length > 0 && customIPs[0] !== "") {
                    return customIPs;
                } else {
                    return [];
                }
            })(),
            "::1",
            "127.0.0.1"
        ],

        knownLabels: (process.env.NERV_COMPUTER_LABELS ?? "")
            .split(",")
            .map(v => v.trim())
    },

    reactor: {
        // reactor maximum allowable temperature
        // in Kelvin
        maxAllowableTemperature: (400 /* deg C */) + 273.15
    }
};