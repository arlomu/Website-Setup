# NodeJS Server Management Script

This script provides a convenient way to manage a NodeJS server with SSL support, file management, and more.

## Features

- Create SSL certificates for secure HTTPS connections.
- Manage server start, stop, and restart.
- Add and optimize PNG images.
- Create and manage HTML files.
- View and clear server logs.

## Requirements

- OpenSSL
- Node.js and npm

## Installation

1. Clone this repository to your local machine.
2. Ensure you have OpenSSL and Node.js installed on your system.
3. Run the script using `sudo bash setup.sh`.
4. Ensure you using Sudo for no Bugs feetures.

## Usage

1. **Set up everything**: This option will create SSL certificates, base files, and start the server.
2. **Create SSL certificate only**: Only creates SSL certificates.
3. **Create base files only**: Creates necessary base files for the server.
4. **Start server**: Starts the NodeJS server.
5. **Stop server**: Stops the running NodeJS server.
6. **Restart server**: Restarts the NodeJS server.
7. **Add new HTML file**: Allows you to add a new HTML file to the server.
8. **Add PNG image**: Optimizes and adds a PNG image to the server.
9. **Show logs**: Displays the last 20 log entries.
10. **Clear logs**: Clears the server log file.

## Notes

- Ensure that the necessary ports (80 for HTTP and 443 for HTTPS) are open and not in use by other applications.
- The script uses `nohup` to run the server in the background and logs output to a specified log file.
- The script assumes you have the necessary permissions to execute commands and access the specified directories.