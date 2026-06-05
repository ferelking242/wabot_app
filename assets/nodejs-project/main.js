// Placeholder — replaced by esbuild bundle during GitHub Actions build
// This file should not run as-is; the real bundle is generated in CI.
const http = require('http');
const PORT = parseInt(process.env.PORT || '3001', 10);
http.createServer((req, res) => {
  res.writeHead(503, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ success: false, error: 'BOT_NOT_BUILT',
    message: 'This is a placeholder bundle. Run the CI pipeline to build the real bot.' }));
}).listen(PORT, '127.0.0.1', () => {
  console.log('[Wabot] Placeholder server on port', PORT);
});
