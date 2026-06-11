// Oracle Node 1 — run: node oracle/node1.js
// Uses PRIVATE_KEY2 from .env (the first oracle node key)
const { OracleNode } = require("./oracle_base");
const node = new OracleNode(1, "PRIVATE_KEY2");
node.start().catch(e => { console.error(e); process.exit(1); });
