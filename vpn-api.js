const express = require('express');
const { execFile } = require('child_process');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = 5888;

const SCRIPTS = {
  vmess: '/opt/vpn-api/scripts/createvmess.sh',
  ssh: '/opt/vpn-api/scripts/createssh.sh',
  vless: '/opt/vpn-api/scripts/createvless.sh',
  trojan: '/opt/vpn-api/scripts/createtrojan.sh',
  renewvmess: '/opt/vpn-api/scripts/renewvmess.sh',
  renewvless: '/opt/vpn-api/scripts/renewvless.sh',
  renewtrojan: '/opt/vpn-api/scripts/renewtrojan.sh',
  renewssh: '/opt/vpn-api/scripts/renewssh.sh',
  cekuserssh: '/opt/vpn-api/scripts/cekuserssh.sh',
  cekusertrojan: '/opt/vpn-api/scripts/cekusertrojan.sh',
  cekuservless: '/opt/vpn-api/scripts/cekuservless.sh',
  cekuservmess: '/opt/vpn-api/scripts/cekuservmess.sh',
  deletessh: '/opt/vpn-api/scripts/deletessh.sh',
  deletevmess: '/opt/vpn-api/scripts/deletevmess.sh',
  deletevless: '/opt/vpn-api/scripts/deletevless.sh',
  deletetrojan: '/opt/vpn-api/scripts/deletetrojan.sh',
  backupserver: '/opt/vpn-api/scripts/backupserver.sh',
  restoreserver: '/opt/vpn-api/scripts/restoreserver.sh'
};

app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

function handleScriptRequest(req, res, scriptType, requiredParams) {
  if (!SCRIPTS[scriptType]) {
    console.error(`Script ${scriptType} not configured`);
    return res.status(500).json({
      status: 'error',
      message: 'Service not available'
    });
  }

  const query = req.query;

  // Validasi parameter
  const missingParams = requiredParams.filter(p => !query[p]);
  if (missingParams.length > 0) {
    return res.status(400).json({
      status: 'error',
      message: `Missing required parameter(s): ${missingParams.join(', ')}`,
      example: getExampleUsage(scriptType)
    });
  }

  // Validasi auth key pakai .env
  if (query.auth !== process.env.AUTHKEY) {
    return res.status(403).json({
      status: 'error',
      message: 'Invalid authentication key'
    });
  }

  // Bangun QUERY_STRING
  const queryString = Object.entries(query)
    .map(([key, val]) => `${key}=${encodeURIComponent(val)}`)
    .join('&');

  // Jalankan script dengan timeout
  const controller = new AbortController();
  const { signal } = controller;
  const timeout = setTimeout(() => {
    controller.abort();
  }, 10000); // Timeout 10 detik

  execFile(SCRIPTS[scriptType], {
    signal,
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString
    }
  }, (error, stdout, stderr) => {
    clearTimeout(timeout);
    const output = stdout.toString().trim();
    const err = stderr.toString().trim();

    try {
      const result = output ? JSON.parse(output) : { status: 'success', message: 'Command executed successfully' };
      return res.status(200).json(result);
    } catch (e) {
      if (error) {
        console.error(`[ERROR] ${scriptType}:`, error);
        const errorMessage = error.code === 'ABORT_ERR'
          ? 'Script execution timeout'
          : (err || error.message || 'Internal server error');
        return res.status(500).json({
          status: 'error',
          message: 'Internal server error',
          details: errorMessage
        });
      }
      if (output) {
        return res.status(200).send(output);
      }
      return res.status(200).json({ status: 'success', message: 'Command executed with no output' });
    }
  });
}

// ====================== ENDPOINTS =========================
// CREATE/RENEW/DELETE/CEK ALL
app.get('/createvmess',     (req, res) => handleScriptRequest(req, res, 'vmess',      ['user', 'exp', 'quota', 'iplimit', 'auth']));
app.get('/createssh',       (req, res) => handleScriptRequest(req, res, 'ssh',        ['user', 'pass', 'exp', 'quota', 'iplimit', 'auth']));
app.get('/createvless',     (req, res) => handleScriptRequest(req, res, 'vless',      ['user', 'exp', 'quota', 'iplimit', 'auth']));
app.get('/createtrojan',    (req, res) => handleScriptRequest(req, res, 'trojan',     ['user', 'exp', 'quota', 'iplimit', 'auth']));
app.get('/renewvmess',      (req, res) => handleScriptRequest(req, res, 'renewvmess', ['user', 'masaaktif', 'quota', 'iplimit', 'auth']));
app.get('/renewvless',      (req, res) => handleScriptRequest(req, res, 'renewvless', ['user', 'masaaktif', 'quota', 'iplimit', 'auth']));
app.get('/renewtrojan',     (req, res) => handleScriptRequest(req, res, 'renewtrojan',['user', 'masaaktif', 'quota', 'iplimit', 'auth']));
app.get('/renewssh',        (req, res) => handleScriptRequest(req, res, 'renewssh',   ['user', 'days', 'auth']));
app.get('/cekuserssh',      (req, res) => handleScriptRequest(req, res, 'cekuserssh', ['auth']));
app.get('/cekusertrojan',   (req, res) => handleScriptRequest(req, res, 'cekusertrojan',['auth']));
app.get('/cekuservless',    (req, res) => handleScriptRequest(req, res, 'cekuservless',['auth']));
app.get('/cekuservmess',    (req, res) => handleScriptRequest(req, res, 'cekuservmess',['auth']));
app.get('/deletessh',       (req, res) => handleScriptRequest(req, res, 'deletessh',  ['user', 'auth']));
app.get('/deletevmess',     (req, res) => handleScriptRequest(req, res, 'deletevmess',['user', 'auth']));
app.get('/deletevless',     (req, res) => handleScriptRequest(req, res, 'deletevless',['user', 'auth']));
app.get('/deletetrojan',    (req, res) => handleScriptRequest(req, res, 'deletetrojan',['user', 'auth']));

// BACKUP SERVER
app.get('/backupserver', (req, res) => {
  const { action, email, auth } = req.query;
  if (!action || !auth) {
    return res.status(400).json({
      status: 'error',
      message: 'Parameter action dan auth wajib diisi',
      example: getExampleUsage('backupserver')
    });
  }
  if (action !== 'backup') {
    return res.status(400).json({
      status: 'error',
      message: 'Action hanya mendukung "backup"',
      example: getExampleUsage('backupserver')
    });
  }
  if (auth !== process.env.AUTHKEY) {
    return res.status(403).json({
      status: 'error',
      message: 'Invalid authentication key'
    });
  }
  const queryString = Object.entries(req.query)
    .map(([key, val]) => `${key}=${encodeURIComponent(val)}`)
    .join('&');
  const controller = new AbortController();
  const { signal } = controller;
  const timeout = setTimeout(() => {
    controller.abort();
  }, 30000);
  execFile(SCRIPTS.backupserver, {
    signal,
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString
    }
  }, (error, stdout, stderr) => {
    clearTimeout(timeout);
    const output = stdout.toString().trim();
    const err = stderr.toString().trim();
    try {
      const result = output ? JSON.parse(output) : { status: 'error', message: 'No output from backup script' };
      return res.status(200).json(result);
    } catch (e) {
      if (error) {
        console.error('[ERROR] backupserver:', error);
        const errorMessage = error.code === 'ABORT_ERR'
          ? 'Backup process timeout'
          : (err || error.message || 'Internal server error during backup');
        return res.status(500).json({
          status: 'error',
          message: 'Backup failed',
          details: errorMessage
        });
      }
      if (output) {
        return res.status(200).send(output);
      }
      return res.status(500).json({
        status: 'error',
        message: 'Backup completed but no output received'
      });
    }
  });
});

// RESTORE SERVER
app.get('/restoreserver', (req, res) => {
  const { action, linkbackup, auth } = req.query;
  if (!action || !linkbackup || !auth) {
    return res.status(400).json({
      status: 'error',
      message: 'Parameter action, linkbackup dan auth wajib diisi',
      example: getExampleUsage('restoreserver')
    });
  }
  if (action !== 'restore') {
    return res.status(400).json({
      status: 'error',
      message: 'Action hanya mendukung "restore"',
      example: getExampleUsage('restoreserver')
    });
  }
  if (auth !== process.env.AUTHKEY) {
    return res.status(403).json({
      status: 'error',
      message: 'Invalid authentication key'
    });
  }
  if (!linkbackup.startsWith('http://') && !linkbackup.startsWith('https://')) {
    return res.status(400).json({
      status: 'error',
      message: 'Link backup harus berupa URL yang valid (http:// atau https://)'
    });
  }
  console.log(`[RESTORE] Starting restore process from: ${linkbackup}`);
  const queryString = Object.entries(req.query)
    .map(([key, val]) => `${key}=${encodeURIComponent(val)}`)
    .join('&');
  const controller = new AbortController();
  const { signal } = controller;
  const timeout = setTimeout(() => {
    controller.abort();
  }, 600000);
  execFile(SCRIPTS.restoreserver, {
    signal,
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString
    }
  }, (error, stdout, stderr) => {
    clearTimeout(timeout);
    if (stdout) {
      const output = stdout.toString().trim();
      try {
        const result = JSON.parse(output);
        return res.status(200).json(result);
      } catch (e) {
        return res.status(200).send(output);
      }
    }
    if (error) {
      console.error('[RESTORE ERROR]', error);
      const errorMessage = error.code === 'ABORT_ERR'
        ? 'Restore process timeout'
        : (error.message || 'Internal server error during restore');
      return res.status(500).json({
        status: 'error',
        message: 'Restore failed',
        details: errorMessage,
        stderr: stderr.toString()
      });
    }
    return res.status(500).json({
      status: 'error',
      message: 'Restore completed but no output received'
    });
  });
});

// Example usage generator
function getExampleUsage(scriptType) {
  const baseUrl = `http://localhost:${PORT}`;
  const examples = {
    vmess: `${baseUrl}/createvmess?user=testuser&exp=30&quota=10&iplimit=2&auth=${process.env.AUTHKEY}`,
    ssh: `${baseUrl}/createssh?user=sshuser&pass=sshpass&exp=30&quota=5&iplimit=1&auth=${process.env.AUTHKEY}`,
    vless: `${baseUrl}/createvless?user=vlessuser&exp=30&quota=15&iplimit=3&auth=${process.env.AUTHKEY}`,
    trojan: `${baseUrl}/createtrojan?user=trojanuser&exp=30&quota=20&iplimit=2&auth=${process.env.AUTHKEY}`,
    renewvmess: `${baseUrl}/renewvmess?user=existinguser&masaaktif=30&quota=5&iplimit=2&auth=${process.env.AUTHKEY}`,
    renewvless: `${baseUrl}/renewvless?user=existingvlessuser&masaaktif=30&quota=10&iplimit=3&auth=${process.env.AUTHKEY}`,
    renewtrojan: `${baseUrl}/renewtrojan?user=existingtrojanuser&masaaktif=30&quota=15&iplimit=2&auth=${process.env.AUTHKEY}`,
    renewssh: `${baseUrl}/renewssh?user=existingsshuser&days=30&auth=${process.env.AUTHKEY}`,
    cekuserssh: `${baseUrl}/cekuserssh?auth=${process.env.AUTHKEY}`,
    cekusertrojan: `${baseUrl}/cekusertrojan?auth=${process.env.AUTHKEY}`,
    cekuservless: `${baseUrl}/cekuservless?auth=${process.env.AUTHKEY}`,
    cekuservmess: `${baseUrl}/cekuservmess?auth=${process.env.AUTHKEY}`,
    deletessh: `${baseUrl}/deletessh?user=sshuser&auth=${process.env.AUTHKEY}`,
    deletevmess: `${baseUrl}/deletevmess?user=vmessuser&auth=${process.env.AUTHKEY}`,
    deletevless: `${baseUrl}/deletevless?user=vlessuser&auth=${process.env.AUTHKEY}`,
    deletetrojan: `${baseUrl}/deletetrojan?user=trojanuser&auth=${process.env.AUTHKEY}`,
    backupserver: [
      `${baseUrl}/backupserver?action=backup&email=youremail@example.com&auth=${process.env.AUTHKEY}`,
      `${baseUrl}/backupserver?action=backup&auth=${process.env.AUTHKEY}`
    ],
    restoreserver: `${baseUrl}/restoreserver?action=restore&linkbackup=https://example.com/backup.zip&auth=${process.env.AUTHKEY}`
  };
  return examples[scriptType] || `${baseUrl}/${scriptType}?param1=value1&auth=${process.env.AUTHKEY}`;
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    services: Object.keys(SCRIPTS),
    timestamp: new Date().toISOString()
  });
});

// Handle 404
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Endpoint not found',
    available_endpoints: [
      'GET /createvmess',
      'GET /createssh',
      'GET /createvless',
      'GET /createtrojan',
      'GET /renewvmess',
      'GET /renewvless',
      'GET /renewtrojan',
      'GET /renewssh',
      'GET /cekuserssh',
      'GET /cekusertrojan',
      'GET /cekuservless',
      'GET /cekuservmess',
      'GET /deletessh',
      'GET /deletevmess',
      'GET /deletevless',
      'GET /deletetrojan',
      'GET /backupserver',
      'GET /restoreserver',
      'GET /health'
    ]
  });
});

const server = app.listen(PORT, () => {
  console.log(`🚀 VPN API Service running on port ${PORT}`);
  console.log('Available endpoints:');
  console.log(`- CREATE VMESS:      http://localhost:${PORT}/createvmess`);
  console.log(`- CREATE SSH:        http://localhost:${PORT}/createssh`);
  console.log(`- CREATE VLESS:      http://localhost:${PORT}/createvless`);
  console.log(`- CREATE TROJAN:     http://localhost:${PORT}/createtrojan`);
  console.log(`- RENEW VMESS:       http://localhost:${PORT}/renewvmess`);
  console.log(`- RENEW VLESS:       http://localhost:${PORT}/renewvless`);
  console.log(`- RENEW TROJAN:      http://localhost:${PORT}/renewtrojan`);
  console.log(`- RENEW SSH:         http://localhost:${PORT}/renewssh`);
  console.log(`- CEK USER SSH:      http://localhost:${PORT}/cekuserssh`);
  console.log(`- CEK USER TROJAN:   http://localhost:${PORT}/cekusertrojan`);
  console.log(`- CEK USER VLESS:    http://localhost:${PORT}/cekuservless`);
  console.log(`- CEK USER VMESS:    http://localhost:${PORT}/cekuservmess`);
  console.log(`- DELETE USER SSH:   http://localhost:${PORT}/deletessh`);
  console.log(`- DELETE USER VMESS: http://localhost:${PORT}/deletevmess`);
  console.log(`- DELETE USER VLESS: http://localhost:${PORT}/deletevless`);
  console.log(`- DELETE USER TROJAN:http://localhost:${PORT}/deletetrojan`);
  console.log(`- BACKUP SERVER:     http://localhost:${PORT}/backupserver`);
  console.log(`- RESTORE SERVER:    http://localhost:${PORT}/restoreserver`);
  console.log(`- Health check:      http://localhost:${PORT}/health`);
});


// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  server.close(() => {
    console.log('🔴 Server closed');
    process.exit(0);
  });
});
