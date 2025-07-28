const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// SSL Zertifikate
const sslOptions = {
    key: fs.readFileSync('./ssl/server.key'),
    cert: fs.readFileSync('./ssl/server.crt')
};

// Server Konfiguration
const HTTP_PORT = 80;
const HTTPS_PORT = 443;

// Dateiendungen zu MIME-Typen
const mimeTypes = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.txt': 'text/plain'
};

// Request Handler
const handleRequest = (req, res) => {
    let filePath = path.join(__dirname, 'public', 
        req.url === '/' ? 'index.html' : req.url);
    
    let extname = path.extname(filePath);
    let contentType = mimeTypes[extname] || 'text/html';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                // Datei nicht gefunden
                fs.readFile(path.join(__dirname, 'public', '404.html'), (err, notFoundContent) => {
                    res.writeHead(404, { 'Content-Type': 'text/html' });
                    res.end(notFoundContent || '404 Not Found');
                });
            } else {
                // Server Fehler
                res.writeHead(500);
                res.end(`Server Error: ${err.code}`);
            }
        } else {
            // Erfolgreiche Antwort
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
};

// Server erstellen
const httpServer = http.createServer(handleRequest);
const httpsServer = https.createServer(sslOptions, handleRequest);

// Server starten
httpServer.listen(HTTP_PORT, () => {
    console.log(`HTTP Server läuft auf http://localhost:${HTTP_PORT}`);
});

httpsServer.listen(HTTPS_PORT, () => {
    console.log(`HTTPS Server läuft auf https://localhost:${HTTPS_PORT}`);
});

// Graceful Shutdown
process.on('SIGTERM', () => {
    httpServer.close();
    httpsServer.close();
    process.exit(0);
});
