#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths and configuration
SSL_DIR="./ssl"
PUBLIC_DIR="./public"
PNG_DIR="$PUBLIC_DIR/png"
CONFIG_FILE="./config.yml"
SERVER_PID_FILE="./server.pid"
LOG_FILE="./server.log"

# Functions
create_ssl_cert() {
    echo -e "${YELLOW}Creating SSL certificate...${NC}"
    mkdir -p "$SSL_DIR"
    openssl req -x509 -newkey rsa:8192 -sha256 -days 3650 -nodes \
        -keyout "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" \
        -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SSL certificate created successfully!${NC}"
        echo -e "Key: ${BLUE}${SSL_DIR}/server.key${NC}"
        echo -e "Cert: ${BLUE}${SSL_DIR}/server.crt${NC}"
    else
        echo -e "${RED}Error creating SSL certificate!${NC}"
        return 1
    fi
}

optimize_png() {
    local input_file=$1
    local output_file=$2

    if ! command -v pngquant &> /dev/null; then
        echo -e "${YELLOW}pngquant not installed, skipping optimization${NC}"
        cp "$input_file" "$output_file"
        return 0
    fi

    pngquant --quality=65-80 --force --output "$output_file" "$input_file"

    if [ $? -eq 0 ]; then
        original_size=$(stat -c%s "$input_file")
        optimized_size=$(stat -c%s "$output_file")
        reduction=$((100 - optimized_size * 100 / original_size))

        echo -e "${GREEN}Image optimized!${NC} Reduction: ${BLUE}${reduction}%${NC}"
        echo -e "Original: ${BLUE}$((original_size/1024)) kB${NC}"
        echo -e "Optimized: ${BLUE}$((optimized_size/1024)) kB${NC}"
    else
        echo -e "${YELLOW}Optimization failed, using original${NC}"
        cp "$input_file" "$output_file"
    fi
}

add_png_image() {
    echo -e "${YELLOW}Add new PNG image file${NC}"

    # Check if pngquant is installed
    if ! command -v pngquant &> /dev/null; then
        echo -e "${YELLOW}Note: pngquant is not installed. Images will not be optimized.${NC}"
        echo -e "Install it with: ${BLUE}sudo apt-get install pngquant${NC}"
    fi

    read -p "Source file (path to PNG image): " source_file
    if [[ ! -f "$source_file" ]]; then
        echo -e "${RED}File not found!${NC}"
        return 1
    fi

    if [[ "$(file -b --mime-type "$source_file")" != "image/png" ]]; then
        echo -e "${RED}The file is not a PNG image!${NC}"
        return 1
    fi

    read -p "Filename (without .png): " filename
    if [[ -z "$filename" ]]; then
        echo -e "${RED}No filename specified!${NC}"
        return 1
    fi

    mkdir -p "$PNG_DIR"
    output_file="$PNG_DIR/${filename}.png"

    if [[ -f "$output_file" ]]; then
        echo -e "${YELLOW}File already exists. Overwrite? (y/n)${NC}"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi

    # Optimize image
    optimize_png "$source_file" "$output_file"

    # Create HTML template with image link
    html_file="$PUBLIC_DIR/${filename}_image.html"

    cat > "$html_file" << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image: ${filename}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            max-width: 1000px;
            margin: 0 auto;
            text-align: center;
        }
        h1 { color: #35424a; }
        img {
            max-width: 100%;
            height: auto;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            margin: 20px 0;
        }
        .info {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            text-align: left;
        }
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
    <h1>Image: ${filename}</h1>

    <div class="info">
        <p><strong>Direct image link:</strong></p>
        <code>/png/${filename}.png</code>

        <p><strong>HTML Code:</strong></p>
        <code>&lt;img src="/png/${filename}.png" alt="${filename}"&gt;</code>
    </div>

    <img src="/png/${filename}.png" alt="${filename}">

    <a href="/" class="back-link">Back to Home</a>
</body>
</html>
EOL
    echo -e "${GREEN}Image added successfully!${NC}"
    echo -e "Image path: ${BLUE}${output_file}${NC}"
    echo -e "HTML page: ${BLUE}${html_file}${NC}"
    echo -e "Direct link: ${BLUE}https://localhost/png/${filename}.png${NC}"

    if [[ -f "$SERVER_PID_FILE" ]]; then
        restart_server
    fi
}

create_app_js() {
    echo -e "${YELLOW}Creating app.js with HTTP/HTTPS support...${NC}"

    cat > app.js << 'EOL'
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// SSL certificates
const sslOptions = {
    key: fs.readFileSync('./ssl/server.key'),
    cert: fs.readFileSync('./ssl/server.crt')
};

// Server configuration
const HTTP_PORT = 80;
const HTTPS_PORT = 443;

// File extensions to MIME types
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

// Cache-Control header for static files
const staticFileCacheControl = {
    '.html': 'no-cache',
    '.js': 'public, max-age=604800',
    '.css': 'public, max-age=604800',
    '.png': 'public, max-age=604800',
    '.jpg': 'public, max-age=604800',
    '.svg': 'public, max-age=604800',
    '.ico': 'public, max-age=604800'
};

// Request handler
const handleRequest = (req, res) => {
    let filePath = path.join(__dirname, 'public',
        req.url === '/' ? 'index.html' : req.url);

    let extname = path.extname(filePath);
    let contentType = mimeTypes[extname] || 'text/html';

    // Set Cache-Control header
    if (staticFileCacheControl[extname]) {
        res.setHeader('Cache-Control', staticFileCacheControl[extname]);
    }

    fs.readFile(filePath, (err, content) => {
        if (err) {
            if (err.code === 'ENOENT') {
                // File not found
                fs.readFile(path.join(__dirname, 'public', '404.html'), (err, notFoundContent) => {
                    res.writeHead(404, { 'Content-Type': 'text/html' });
                    res.end(notFoundContent || '404 Not Found');
                });
            } else {
                // Server error
                res.writeHead(500);
                res.end(`Server Error: ${err.code}`);
            }
        } else {
            // Successful response
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
};

// Create servers
const httpServer = http.createServer(handleRequest);
const httpsServer = https.createServer(sslOptions, handleRequest);

// Start servers
httpServer.listen(HTTP_PORT, () => {
    console.log(`HTTP Server running on http://localhost:${HTTP_PORT}`);
});

httpsServer.listen(HTTPS_PORT, () => {
    console.log(`HTTPS Server running on https://localhost:${HTTPS_PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    httpServer.close();
    httpsServer.close();
    process.exit(0);
});
EOL
    echo -e "${GREEN}app.js created successfully!${NC}"
}

create_base_files() {
    echo -e "${YELLOW}Creating base files...${NC}"

    # Public directory
    mkdir -p "$PUBLIC_DIR"
    mkdir -p "$PNG_DIR"

    # Index HTML
    cat > "$PUBLIC_DIR/index.html" << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My NodeJS Server</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; }
        header { background: #35424a; color: white; padding: 20px; text-align: center; }
        .container { max-width: 800px; margin: 0 auto; }
        .menu { margin: 20px 0; }
        .menu a { display: inline-block; margin: 0 10px 10px 0; padding: 8px 15px;
                 background: #35424a; color: white; text-decoration: none; border-radius: 4px; }
        .menu a:hover { background: #4e5d6c; }
        .image-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 15px; }
        .image-item { border: 1px solid #ddd; padding: 10px; border-radius: 5px; text-align: center; }
        .image-item img { max-width: 100%; height: auto; }
        footer { margin-top: 20px; text-align: center; color: #666; }
    </style>
</head>
<body>
    <header>
        <h1>Welcome to My Server</h1>
    </header>

    <div class="container">
        <div class="menu">
            <a href="/">Home</a>
            <a href="/info.html">Server Info</a>
            <a href="/add_image.html">Add Image</a>
        </div>

        <h2>Features</h2>
        <ul>
            <li>HTTPS with self-signed certificate</li>
            <li>Automatic file detection</li>
            <li>Support for many file types</li>
            <li>Automatic image optimization (PNG)</li>
        </ul>

        <h2>Images</h2>
        <div class="image-grid" id="image-grid">
            <!-- Images will be loaded dynamically -->
        </div>
    </div>

    <footer>
        <p>Server started on <span id="server-date"></span></p>
    </footer>
    <script>
        // Display server date
        document.getElementById('server-date').textContent = new Date().toLocaleString();

        // Load available images
        fetch('/png-list')
            .then(response => response.json())
            .then(images => {
                const grid = document.getElementById('image-grid');
                images.forEach(image => {
                    const imageItem = document.createElement('div');
                    imageItem.className = 'image-item';
                    imageItem.innerHTML = `
                        <img src="/png/${image}" alt="${image}">
                        <div>${image}</div>
                        <a href="/png/${image}" target="_blank">Full Size</a>
                    `;
                    grid.appendChild(imageItem);
                });
            });
    </script>
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
    <pre id="server-info">Loading information...</pre>

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
    <p>The requested page was not found.</p>
    <p><a href="/">Back to Home</a></p>
</body>
</html>
EOL

    # Add Image HTML
    cat > "$PUBLIC_DIR/add_image.html" << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Add Image</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            max-width: 800px;
            margin: 0 auto;
        }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input[type="text"], input[type="file"] {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        button {
            background: #35424a;
            color: white;
            border: none;
            padding: 10px 15px;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover { background: #4e5d6c; }
        .back-link {
            display: inline-block;
            margin-top: 20px;
            padding: 8px 15px;
            background: #f0f0f0;
            color: #333;
            text-decoration: none;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <h1>Add Image</h1>

    <form id="upload-form">
        <div class="form-group">
            <label for="image-file">Select PNG Image:</label>
            <input type="file" id="image-file" accept=".png" required>
        </div>

        <div class="form-group">
            <label for="image-name">Filename (without .png):</label>
            <input type="text" id="image-name" placeholder="my-image" required>
        </div>

        <button type="submit">Upload Image</button>
    </form>

    <div id="upload-status" style="margin-top: 20px;"></div>

    <a href="/" class="back-link">Back to Home</a>

    <script>
        document.getElementById('upload-form').addEventListener('submit', function(e) {
            e.preventDefault();

            const fileInput = document.getElementById('image-file');
            const nameInput = document.getElementById('image-name');
            const statusDiv = document.getElementById('upload-status');

            const file = fileInput.files[0];
            const filename = nameInput.value.trim();

            if (!file || !filename) {
                statusDiv.innerHTML = '<p style="color: red;">Please fill in all fields!</p>';
                return;
            }

            if (file.type !== 'image/png') {
                statusDiv.innerHTML = '<p style="color: red;">Only PNG files are allowed!</p>';
                return;
            }

            const formData = new FormData();
            formData.append('image', file);
            formData.append('name', filename);

            statusDiv.innerHTML = '<p>Uploading and optimizing image...</p>';

            fetch('/upload-png', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    statusDiv.innerHTML = `
                        <p style="color: green;">Image uploaded successfully!</p>
                        <p><strong>Direct Link:</strong> <a href="${data.imageUrl}" target="_blank">${data.imageUrl}</a></p>
                        <p><strong>HTML Code:</strong></p>
                        <code>&lt;img src="${data.imageUrl}" alt="${filename}"&gt;</code>
                        <p><a href="${data.htmlUrl}" target="_blank">View Image Page</a></p>
                    `;
                } else {
                    statusDiv.innerHTML = `<p style="color: red;">Error: ${data.message}</p>`;
                }
            })
            .catch(error => {
                statusDiv.innerHTML = `<p style="color: red;">Upload error: ${error.message}</p>`;
            });
        });
    </script>
</body>
</html>
EOL

    echo -e "${GREEN}Base files created successfully!${NC}"
}

add_html_file() {
    echo -e "${YELLOW}Add new HTML file${NC}"
    read -p "Filename (without .html): " filename

    if [[ -z "$filename" ]]; then
        echo -e "${RED}No filename specified!${NC}"
        return 1
    fi

    html_file="$PUBLIC_DIR/${filename}.html"

    if [[ -f "$html_file" ]]; then
        echo -e "${YELLOW}File already exists. Overwrite? (y/n)${NC}"
        read -r overwrite
        if [[ ! "$overwrite" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi

    cat > "$html_file" << EOL
<!DOCTYPE html>
<html lang="en">
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
    <p>This is your new page.</p>
    <p>Edit this content in the file: <code>public/${filename}.html</code></p>

    <a href="/" class="back-link">Back to Home</a>
</body>
</html>
EOL
    echo -e "${GREEN}File ${BLUE}${html_file}${GREEN} created successfully!${NC}"

    if [[ -f "$SERVER_PID_FILE" ]]; then
        restart_server
    fi
}

start_server() {
    if [[ -f "$SERVER_PID_FILE" ]]; then
        echo -e "${YELLOW}Server is already running (PID $(cat "$SERVER_PID_FILE"))${NC}"
        return 1
    fi

    echo -e "${YELLOW}Starting server...${NC}"
    nohup node app.js >> "$LOG_FILE" 2>&1 &
    echo $! > "$SERVER_PID_FILE"

    sleep 2

    if ps -p $(cat "$SERVER_PID_FILE") > /dev/null; then
        echo -e "${GREEN}Server started successfully!${NC}"
        echo -e "HTTP:  ${BLUE}http://localhost:80${NC}"
        echo -e "HTTPS: ${BLUE}https://localhost:443${NC}"
        echo -e "Logs:  ${BLUE}${LOG_FILE}${NC}"
    else
        echo -e "${RED}Failed to start server!${NC}"
        echo -e "Check the logs: ${BLUE}${LOG_FILE}${NC}"
        rm "$SERVER_PID_FILE"
        return 1
    fi
}

stop_server() {
    if [[ ! -f "$SERVER_PID_FILE" ]]; then
        echo -e "${YELLOW}Server is not started${NC}"
        return 1
    fi

    pid=$(cat "$SERVER_PID_FILE")
    echo -e "${YELLOW}Stopping server (PID $pid)...${NC}"

    if kill "$pid"; then
        rm "$SERVER_PID_FILE"
        echo -e "${GREEN}Server stopped successfully!${NC}"
    else
        echo -e "${RED}Failed to stop server!${NC}"
        return 1
    fi
}

restart_server() {
    stop_server
    start_server
}

show_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}No log file available${NC}"
        return 1
    fi

    echo -e "${YELLOW}Last log entries:${NC}"
    tail -20 "$LOG_FILE"
}

clear_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}No log file available${NC}"
        return 1
    fi

    > "$LOG_FILE"
    echo -e "${GREEN}Logs cleared!${NC}"
}

show_menu() {
    clear
    echo -e "${GREEN}NodeJS Server Management${NC}"
    echo -e "========================"
    echo -e "1. Set up everything (SSL + Files + Start Server)"
    echo -e "2. Create SSL certificate only"
    echo -e "3. Create base files only"
    echo -e "4. Start server"
    echo -e "5. Stop server"
    echo -e "6. Restart server"
    echo -e "7. Add new HTML file"
    echo -e "8. Add PNG image"
    echo -e "9. Show logs"
    echo -e "10. Clear logs"
    echo -e "0. Exit"
    echo -e "========================"

    read -p "Select an option [0-10]: " choice

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
        8) add_png_image ;;
        9) show_logs ;;
        10) clear_logs ;;
        0) exit 0 ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            ;;
    esac

    read -p "Press any key to continue..." -n1 -s
    show_menu
}

# Main program
echo -e "${GREEN}NodeJS Server Setup Script${NC}"
echo -e "=========================="

# Check for required packages
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}OpenSSL is not installed!${NC}"
    echo -e "${YELLOW}Install it with: apt-get install openssl${NC}"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js is not installed!${NC}"
    echo -e "${YELLOW}Install it with: apt-get install nodejs npm${NC}"
    exit 1
fi

show_menu