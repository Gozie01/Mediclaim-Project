// Oracle Node 3 — run: node oracle/node3.js
// Uses PRIVATE_KEY4 from .env (the third oracle node key)
const { OracleNode } = require("./oracle_base");
const node = new OracleNode(3, "PRIVATE_KEY4");
node.start().catch(e => { console.error(e); process.exit(1); });
