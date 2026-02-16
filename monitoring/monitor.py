"""
Detooz Monitoring Dashboard
Run this script to start a local monitoring server.
Open http://localhost:5050 to view the dashboard.
"""

import subprocess
import json
from http.server import HTTPServer, SimpleHTTPRequestHandler
import urllib.parse
import os

# Configuration
EC2_IP = "3.108.220.220"
SSH_KEY = os.path.expanduser("C:/CP/plans/Detooz/detooz-key.pem")
EC2_USER = "ubuntu"

HTML_DASHBOARD = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Detooz Monitoring Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #e0e0e0;
            min-height: 100vh;
            padding: 20px;
        }
        .header {
            text-align: center;
            padding: 20px;
            margin-bottom: 20px;
        }
        .header h1 {
            font-size: 2rem;
            background: linear-gradient(90deg, #00d2ff, #3a7bd5);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        .status-bar {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin-bottom: 20px;
        }
        .status-item {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 20px;
            background: rgba(255,255,255,0.05);
            border-radius: 20px;
        }
        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        .status-dot.healthy { background: #00ff88; }
        .status-dot.unhealthy { background: #ff4444; }
        .status-dot.loading { background: #ffaa00; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .controls {
            display: flex;
            justify-content: center;
            gap: 15px;
            margin-bottom: 20px;
        }
        button {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            transition: all 0.3s;
        }
        .btn-primary {
            background: linear-gradient(90deg, #00d2ff, #3a7bd5);
            color: white;
        }
        .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 4px 15px rgba(0,210,255,0.4); }
        .btn-secondary {
            background: rgba(255,255,255,0.1);
            color: white;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .btn-secondary:hover { background: rgba(255,255,255,0.2); }
        .log-container {
            background: rgba(0,0,0,0.3);
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .log-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .log-header h2 {
            font-size: 1.2rem;
            color: #00d2ff;
        }
        .log-content {
            background: #0a0a14;
            border-radius: 8px;
            padding: 15px;
            max-height: 400px;
            overflow-y: auto;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 13px;
            line-height: 1.6;
            white-space: pre-wrap;
            word-break: break-all;
        }
        .log-line { margin-bottom: 2px; }
        .log-line.info { color: #00d2ff; }
        .log-line.error { color: #ff6b6b; }
        .log-line.warning { color: #ffd93d; }
        .log-line.success { color: #6bcb77; }
        .auto-refresh {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .auto-refresh label { font-size: 14px; }
        select {
            padding: 8px 12px;
            border-radius: 6px;
            background: rgba(255,255,255,0.1);
            color: white;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .timestamp {
            font-size: 12px;
            color: #888;
        }
        .error-message {
            color: #ff6b6b;
            padding: 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🛡️ Detooz Monitoring</h1>
        <p>Real-time monitoring for your Detooz deployment</p>
    </div>

    <div class="status-bar">
        <div class="status-item">
            <div class="status-dot loading" id="backendStatus"></div>
            <span>Backend: <span id="backendStatusText">Checking...</span></span>
        </div>
        <div class="status-item">
            <span>EC2: 3.108.220.220</span>
        </div>
    </div>

    <div class="controls">
        <button class="btn-primary" onclick="refreshLogs()">🔄 Refresh Logs</button>
        <button class="btn-secondary" onclick="clearLogs()">🗑️ Clear Display</button>
        <div class="auto-refresh">
            <label>Auto-refresh:</label>
            <select id="refreshInterval" onchange="setAutoRefresh()">
                <option value="0">Off</option>
                <option value="5000">5 seconds</option>
                <option value="10000" selected>10 seconds</option>
                <option value="30000">30 seconds</option>
                <option value="60000">1 minute</option>
            </select>
        </div>
    </div>

    <div class="log-container">
        <div class="log-header">
            <h2>📦 Backend Logs (Docker)</h2>
            <span class="timestamp" id="lastUpdate">Never updated</span>
        </div>
        <div class="log-content" id="backendLogs">
            <p class="log-line info">Loading logs...</p>
        </div>
    </div>

    <div class="log-container">
        <div class="log-header">
            <h2>📱 Frontend Logs</h2>
            <span class="timestamp">Run: flutter logs</span>
        </div>
        <div class="log-content" id="frontendLogs">
            <p class="log-line info">Frontend logs require running "flutter logs" in your terminal while the app is connected.</p>
            <p class="log-line info">For Android production logs, use: adb logcat | grep flutter</p>
        </div>
    </div>

    <script>
        let autoRefreshInterval = null;

        async function checkHealth() {
            const dot = document.getElementById('backendStatus');
            const text = document.getElementById('backendStatusText');
            try {
                const res = await fetch('/api/health');
                const data = await res.json();
                if (data.status === 'healthy') {
                    dot.className = 'status-dot healthy';
                    text.textContent = 'Healthy';
                } else {
                    dot.className = 'status-dot unhealthy';
                    text.textContent = 'Unhealthy';
                }
            } catch (e) {
                dot.className = 'status-dot unhealthy';
                text.textContent = 'Error';
            }
        }

        async function refreshLogs() {
            const container = document.getElementById('backendLogs');
            container.innerHTML = '<p class="log-line info">Fetching logs...</p>';
            
            try {
                const res = await fetch('/api/logs?lines=100');
                const data = await res.json();
                
                if (data.error) {
                    container.innerHTML = `<p class="error-message">${data.error}</p>`;
                    return;
                }
                
                const lines = data.logs.split('\\n').filter(l => l.trim());
                container.innerHTML = lines.map(line => {
                    let cls = 'log-line';
                    if (line.includes('ERROR') || line.includes('error')) cls += ' error';
                    else if (line.includes('WARNING') || line.includes('warning')) cls += ' warning';
                    else if (line.includes('INFO')) cls += ' info';
                    else if (line.includes('200 OK')) cls += ' success';
                    return `<div class="${cls}">${escapeHtml(line)}</div>`;
                }).join('');
                
                document.getElementById('lastUpdate').textContent = 
                    'Last updated: ' + new Date().toLocaleTimeString();
                
                // Scroll to bottom
                container.scrollTop = container.scrollHeight;
            } catch (e) {
                container.innerHTML = `<p class="error-message">Failed to fetch logs: ${e.message}</p>`;
            }
        }

        function clearLogs() {
            document.getElementById('backendLogs').innerHTML = 
                '<p class="log-line info">Logs cleared. Click Refresh to load new logs.</p>';
        }

        function setAutoRefresh() {
            const interval = parseInt(document.getElementById('refreshInterval').value);
            if (autoRefreshInterval) clearInterval(autoRefreshInterval);
            if (interval > 0) {
                autoRefreshInterval = setInterval(() => {
                    refreshLogs();
                    checkHealth();
                }, interval);
            }
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        // Initial load
        checkHealth();
        refreshLogs();
        setAutoRefresh();
    </script>
</body>
</html>
"""

class MonitoringHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        
        if parsed.path == '/' or parsed.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_DASHBOARD.encode())
            
        elif parsed.path == '/api/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            try:
                result = subprocess.run(
                    ['ssh', '-i', SSH_KEY, '-o', 'StrictHostKeyChecking=no', '-o', 'ConnectTimeout=5',
                     f'{EC2_USER}@{EC2_IP}', 'curl -s http://localhost:8000/health'],
                    capture_output=True, text=True, timeout=10
                )
                if '"healthy"' in result.stdout:
                    self.wfile.write(b'{"status": "healthy"}')
                else:
                    self.wfile.write(b'{"status": "unhealthy"}')
            except Exception as e:
                self.wfile.write(f'{{"status": "error", "message": "{str(e)}"}}'.encode())
                
        elif parsed.path.startswith('/api/logs'):
            query = urllib.parse.parse_qs(parsed.query)
            lines = query.get('lines', ['50'])[0]
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            try:
                result = subprocess.run(
                    ['ssh', '-i', SSH_KEY, '-o', 'StrictHostKeyChecking=no', '-o', 'ConnectTimeout=10',
                     f'{EC2_USER}@{EC2_IP}', f'sudo docker logs detooz-backend --tail {lines}'],
                    capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace'
                )
                logs = result.stdout + result.stderr
                # Properly escape for JSON
                response = json.dumps({"logs": logs}, ensure_ascii=False)
                self.wfile.write(response.encode('utf-8'))
            except Exception as e:
                error_msg = str(e).replace('"', '\\"')
                self.wfile.write(f'{{"error": "Failed to fetch logs: {error_msg}"}}'.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def main():
    port = 5055
    server = HTTPServer(('localhost', port), MonitoringHandler)
    print(f"""
+--------------------------------------------------------------+
|                 Detooz Monitoring Server                     |
+--------------------------------------------------------------+
|  Dashboard: http://localhost:{port}                            |
|  EC2 Host:  {EC2_IP}                                   |
+--------------------------------------------------------------+
|  Press Ctrl+C to stop the server                             |
+--------------------------------------------------------------+
    """)
    
    import webbrowser
    webbrowser.open(f'http://localhost:{port}')
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Monitoring server stopped.")
        server.shutdown()

if __name__ == '__main__':
    main()
