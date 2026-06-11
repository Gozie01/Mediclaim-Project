// Oracle Node 2 — run: node oracle/node2.js
// Uses PRIVATE_KEY3 from .env (the second oracle node key)
const { OracleNode } = require("./oracle_base");
const node = new OracleNode(2, "PRIVATE_KEY3");
node.start().catch(e => { console.error(e); process.exit(1); });
