export default function buildMsg(type, data = {}) {
	return JSON.stringify({
		type,
		...data
	});
}