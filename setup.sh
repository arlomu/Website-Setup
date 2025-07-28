#!/bin/bash

# Farbdefinitionen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Pfade und Konfiguration
SSL_DIR="./ssl"
PUBLIC_DIR="./public"
CONFIG_FILE="./config.yml"
SERVER_PID_FILE="./server.pid"
LOG_FILE="./server.log"

# Funktionen
create_ssl_cert() {
    echo -e "${YELLOW}Erstelle SSL-Zertifikat...${NC}"
    mkdir -p "$SSL_DIR"
    openssl req -x509 -newkey rsa:8192 -sha256 -days 3650 -nodes \
        -keyout "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" \
        -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSL-Zertifikat erfolgreich erstellt!${NC}"
        echo -e "Key: ${BLUE}${SSL_DIR}/server.key${NC}"
        echo -e "Cert: ${BLUE}${SSL_DIR}/server.crt${NC}"
    else
        echo -e "${RED}Fehler beim Erstellen des SSL-Zertifikats!${NC}"
        return 1
    fi
}

create_app_js() {
    echo -e "${YELLOW}Erstelle app.js mit HTTP/HTTPS Support...${NC}"
    
    cat > app.js << 'EOL'
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
EOL

    echo -e "${GREEN}app.js erfolgreich erstellt!${NC}"
}

create_base_files() {
    echo -e "${YELLOW}Erstelle Basis-Dateien...${NC}"
    
    # Öffentliches Verzeichnis
    mkdir -p "$PUBLIC_DIR"
    
    # Index HTML
    cat > "$PUBLIC_DIR/index.html" << 'EOL'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mein NodeJS Server</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; }
        header { background: #35424a; color: white; padding: 20px; text-align: center; }
        .container { max-width: 800px; margin: 0 auto; }
        .menu { margin: 20px 0; }
        .menu a { display: inline-block; margin: 0 10px 10px 0; padding: 8px 15px; 
                 background: #35424a; color: white; text-decoration: none; border-radius: 4px; }
        footer { margin-top: 20px; text-align: center; color: #666; }
    </style>
</head>
<body>
    <header>
        <h1>Willkommen auf meinem Server</h1>
    </header>
    
    <div class="container">
        <div class="menu">
            <a href="/">Startseite</a>
            <a href="/info.html">Server Info</a>
        </div>
        
        <h2>Funktionen</h2>
        <ul>
            <li>HTTPS mit selbstsigniertem Zertifikat</li>
            <li>Automatische Datei-Erkennung</li>
            <li>Unterstützung für viele Dateitypen</li>
        </ul>
    </div>
    
    <footer>
        <p>Server gestartet am $(date +"%d.%m.%Y %H:%M:%S")</p>
    </footer>
</body>
</html>
EOL

    # Info HTML
    cat > "$PUBLIC_DIR/info.html" << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Server Information</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; }
        pre { background: #f4f4f4; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Server Information</h1>
    <pre id="server-info">Lade Informationen...</pre>
    
    <script>
        fetch('/server-info')
            .then(response => response.json())
            .then(data => {
                document.getElementById('server-info').innerText = JSON.stringify(data, null, 2);
            });
    </script>
</body>
</html>
EOL

    # 404 HTML
    cat > "$PUBLIC_DIR/404.html" << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>404 Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { font-size: 50px; color: #d9534f; }
    </style>
</head>
<body>
    <h1>404</h1>
    <p>Die angeforderte Seite wurde nicht gefunden.</p>
    <p><a href="/">Zurück zur Startseite</a></p>
</body>
</html>
EOL

    echo -e "${GREEN}Basis-Dateien erfolgreich erstellt!${NC}"
}

add_html_file() {
    echo -e "${YELLOW}Neue HTML-Datei hinzufügen${NC}"
    read -p "Dateiname (ohne .html): " filename
    
    if [[ -z "$filename" ]]; then
        echo -e "${RED}Kein Dateiname angegeben!${NC}"
        return 1
    fi
    
    html_file="$PUBLIC_DIR/${filename}.html"
    
    if [[ -f "$html_file" ]]; then
        echo -e "${YELLOW}Datei existiert bereits. Überschreiben? (j/n)${NC}"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[jJ]$ ]]; then
            return 1
        fi
    fi
    
    cat > "$html_file" << EOL
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${filename}</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            line-height: 1.6; 
            margin: 0; 
            padding: 20px;
            max-width: 800px;
            margin: 0 auto;
        }
        h1 { color: #35424a; }
        .back-link { 
            display: inline-block; 
            margin-top: 20px; 
            padding: 8px 15px; 
            background: #35424a; 
            color: white; 
            text-decoration: none; 
            border-radius: 4px; 
        }
    </style>
</head>
<body>
    <h1>${filename}</h1>
    <p>Dies ist Ihre neue Seite.</p>
    <p>Bearbeiten Sie diesen Inhalt in der Datei: <code>public/${filename}.html</code></p>
    
    <a href="/" class="back-link">Zurück zur Startseite</a>
</body>
</html>
EOL

    echo -e "${GREEN}Datei ${BLUE}${html_file}${GREEN} erfolgreich erstellt!${NC}"
    
    if [[ -f "$SERVER_PID_FILE" ]]; then
        restart_server
    fi
}

start_server() {
    if [[ -f "$SERVER_PID_FILE" ]]; then
        echo -e "${YELLOW}Server läuft bereits (PID $(cat "$SERVER_PID_FILE"))${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Starte Server...${NC}"
    nohup node app.js >> "$LOG_FILE" 2>&1 &
    echo $! > "$SERVER_PID_FILE"
    
    sleep 2
    
    if ps -p $(cat "$SERVER_PID_FILE") > /dev/null; then
        echo -e "${GREEN}Server erfolgreich gestartet!${NC}"
        echo -e "HTTP:  ${BLUE}http://localhost:80${NC}"
        echo -e "HTTPS: ${BLUE}https://localhost:443${NC}"
        echo -e "Logs:  ${BLUE}${LOG_FILE}${NC}"
    else
        echo -e "${RED}Server konnte nicht gestartet werden!${NC}"
        echo -e "Überprüfen Sie die Logs: ${BLUE}${LOG_FILE}${NC}"
        rm "$SERVER_PID_FILE"
        return 1
    fi
}

stop_server() {
    if [[ ! -f "$SERVER_PID_FILE" ]]; then
        echo -e "${YELLOW}Server ist nicht gestartet${NC}"
        return 1
    fi
    
    pid=$(cat "$SERVER_PID_FILE")
    echo -e "${YELLOW}Stoppe Server (PID $pid)...${NC}"
    
    if kill "$pid"; then
        rm "$SERVER_PID_FILE"
        echo -e "${GREEN}Server erfolgreich gestoppt!${NC}"
    else
        echo -e "${RED}Fehler beim Stoppen des Servers!${NC}"
        return 1
    fi
}

restart_server() {
    stop_server
    start_server
}

show_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}Keine Log-Datei vorhanden${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Letzte Log-Einträge:${NC}"
    tail -20 "$LOG_FILE"
}

clear_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}Keine Log-Datei vorhanden${NC}"
        return 1
    fi
    
    > "$LOG_FILE"
    echo -e "${GREEN}Logs wurden geleert!${NC}"
}

show_menu() {
    clear
    echo -e "${GREEN}NodeJS Server Management${NC}"
    echo -e "========================"
    echo -e "1. Alles einrichten (SSL + Dateien + Server starten)"
    echo -e "2. Nur SSL-Zertifikat erstellen"
    echo -e "3. Nur Basis-Dateien erstellen"
    echo -e "4. Server starten"
    echo -e "5. Server stoppen"
    echo -e "6. Server neustarten"
    echo -e "7. Neue HTML-Datei hinzufügen"
    echo -e "8. Logs anzeigen"
    echo -e "9. Logs leeren"
    echo -e "0. Beenden"
    echo -e "========================"
    
    read -p "Auswahl [0-9]: " choice
    
    case $choice in
        1) 
            create_ssl_cert
            create_base_files
            create_app_js
            start_server
            ;;
        2) create_ssl_cert ;;
        3) 
            create_base_files
            create_app_js
            ;;
        4) start_server ;;
        5) stop_server ;;
        6) restart_server ;;
        7) add_html_file ;;
        8) show_logs ;;
        9) clear_logs ;;
        0) exit 0 ;;
        *) 
            echo -e "${RED}Ungültige Auswahl!${NC}"
            sleep 1
            ;;
    esac
    
    read -p "Drücken Sie eine Taste, um fortzufahren..." -n1 -s
    show_menu
}

# Hauptprogramm
echo -e "${GREEN}NodeJS Server Setup Script${NC}"
echo -e "=========================="

# Prüfe auf benötigte Pakete
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}OpenSSL ist nicht installiert!${NC}"
    echo -e "${YELLOW}Installieren Sie es mit: apt-get install openssl${NC}"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js ist nicht installiert!${NC}"
    echo -e "${YELLOW}Installieren Sie es mit: apt-get install nodejs npm${NC}"
    exit 1
fi

show_menu