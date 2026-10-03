// A plain static file server for the web release build.
//
// `flutter run -d web-server` serves a blank page (a DWDS websocket problem),
// so the fast loop is: build a release, serve it statically, refresh.
//
//   node tools/serve.js [dir] [port]
//
// Every response is sent with no-store, so a rebuild is never hidden behind a
// cached copy of the last one.

const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(process.argv[2] || 'build/web');
const port = Number(process.argv[3] || 8080);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.bin': 'application/octet-stream',
};

http
  .createServer((req, res) => {
    const url = decodeURIComponent(req.url.split('?')[0]);
    let file = path.join(root, url);
    if (!file.startsWith(root)) {
      res.writeHead(403).end();
      return;
    }
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) {
      file = path.join(file, 'index.html');
    }
    if (!fs.existsSync(file)) file = path.join(root, 'index.html');

    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404).end('not found');
        return;
      }
      res.writeHead(200, {
        'Content-Type': types[path.extname(file)] || 'application/octet-stream',
        'Cache-Control': 'no-store',
      });
      res.end(data);
    });
  })
  .listen(port, () => {
    console.log(`RapidRX web build at http://localhost:${port}  (serving ${root})`);
  });
