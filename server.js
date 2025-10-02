const http = require('http');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 8080;
const root = process.env.MAINT_ROOT || __dirname;

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
  try {
    const urlPath = decodeURIComponent(new URL(req.url, `http://localhost`).pathname);
    let filePath = path.join(root, urlPath);

    // Normalize directory requests
    if (urlPath === '/') filePath = path.join(root, 'index.html');

    fs.stat(filePath, (err, stats) => {
      if (err) {
        // Fallback to index.html for unknown routes
        const fallback = path.join(root, 'index.html');
        fs.readFile(fallback, (e, data) => {
          if (e) {
            res.writeHead(404, {'Content-Type': 'text/plain'});
            res.end('Not found');
            return;
          }
          res.writeHead(200, {'Content-Type': 'text/html'});
          res.end(data);
        });
        return;
      }

      if (stats.isDirectory()) {
        const indexFile = path.join(filePath, 'index.html');
        fs.readFile(indexFile, (e, data) => {
          if (e) {
            res.writeHead(403, {'Content-Type': 'text/plain'});
            res.end('Forbidden');
            return;
          }
          res.writeHead(200, {'Content-Type': 'text/html'});
          res.end(data);
        });
        return;
      }

      const ext = path.extname(filePath).toLowerCase();
      const type = mime[ext] || 'application/octet-stream';
      fs.readFile(filePath, (e, data) => {
        if (e) {
          res.writeHead(500, {'Content-Type': 'text/plain'});
          res.end('Server error');
          return;
        }
        res.writeHead(200, {'Content-Type': type});
        res.end(data);
      });
    });
  } catch (err) {
    res.writeHead(500, {'Content-Type': 'text/plain'});
    res.end('Server error');
  }
});

server.listen(port, () => {
  console.log(`Maintenance static server running on http://0.0.0.0:${port}, serving ${root}`);
});
