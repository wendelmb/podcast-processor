const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const FILE = path.join(__dirname, 'index.html');

const server = http.createServer((req, res) => {
  fs.readFile(FILE, (err, content) => {
    if (err) { res.writeHead(500); res.end('Erro ao ler index.html'); return; }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(content);
  });
});

server.listen(PORT, () => {
  console.log('\n🎙️  Podcast Processor UI');
  console.log(`   Acesse: http://localhost:${PORT}`);
  console.log('   (Ctrl+C para encerrar)\n');
});
