import { createServer } from 'node:net';

const BUFFER_SIZE = 64 * 1024;
const [portArg = '8080', limitArg] = process.argv.slice(2);
const port = Number(portArg);
const connectionLimit = limitArg === undefined ? Infinity : Number(limitArg);

if (process.argv.length > 4 || !Number.isInteger(port) || port < 0 || port > 65535 ||
    (limitArg !== undefined && (!Number.isSafeInteger(connectionLimit) || connectionLimit <= 0))) {
    console.error('Usage: node NodeEcho.mjs [port] [connection-count]');
    process.exit(1);
}

function publish(event) {
    console.log(JSON.stringify(event));
}

let acceptedCount = 0;
const server = createServer({ noDelay: true, highWaterMark: BUFFER_SIZE }, (socket) => {
    const index = ++acceptedCount;
    let bytes = 0;
    publish({ Kind: 'Accepted', Index: index, Options: [null, null, 1] });

    socket.on('data', (chunk) => {
        bytes += chunk.length;
        if (!socket.write(chunk)) {
            socket.pause();
        }
    });
    socket.on('drain', () => socket.resume());
    socket.on('error', (error) => {
        console.error(error.message);
        process.exitCode = 1;
    });
    socket.on('close', () => publish({ Kind: 'Closed', Index: index, Bytes: bytes }));

    if (index === connectionLimit) {
        server.close();
    }
});

server.on('error', (error) => {
    console.error(error.message);
    process.exitCode = 1;
});

server.listen(port, '127.0.0.1', () => {
    publish({
        Kind: 'Ready',
        Address: `tcp://127.0.0.1:${server.address().port}`,
        PID: process.pid,
        Options: [null, null, null],
        HighWaterMark: BUFFER_SIZE,
        Runtime: process.version,
    });
});
