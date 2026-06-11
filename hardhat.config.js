require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// Hardhat default keys as placeholders — replace with real PureChain keys in .env
const PRIVATE_KEY  = process.env.PRIVATE_KEY  || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const PRIVATE_KEY2 = process.env.PRIVATE_KEY2 || "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const PRIVATE_KEY3 = process.env.PRIVATE_KEY3 || "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";
const PRIVATE_KEY4 = process.env.PRIVATE_KEY4 || "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6";
const PRIVATE_KEY5 = process.env.PRIVATE_KEY5 || "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b";
const PRIVATE_KEY6 = process.env.PRIVATE_KEY6 || "0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba";
const PRIVATE_KEY7 = process.env.PRIVATE_KEY7 || "0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e";
const PRIVATE_KEY8 = process.env.PRIVATE_KEY8 || "0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356";
const PRIVATE_KEY9 = process.env.PRIVATE_KEY9 || "0xdbda1821b80551c9d65939329250132c444b1a9f1a4f50f9a0c0a040d53ccff6";
const PRIVATE_KEY10= process.env.PRIVATE_KEY10|| "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
    },
  },

  networks: {
    purechain: {
      url:      "https://purechainnode.com",
      chainId:  900520900520,
      accounts: [PRIVATE_KEY, PRIVATE_KEY2, PRIVATE_KEY3, PRIVATE_KEY4,
                 PRIVATE_KEY5, PRIVATE_KEY6, PRIVATE_KEY7, PRIVATE_KEY8,
                 PRIVATE_KEY9, PRIVATE_KEY10],
      gasPrice: 0,       // PureChain is gasless (0 Gwei shown on explorer)
      gas:      8000000, // explicit gas limit
      timeout:  180000,
    },
    hardhat: { chainId: 31337 },
    localhost: {
      url:     "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },

  gasReporter: {
    enabled:    true,
    currency:   "USD",
    outputFile: "benchmarks/gas_report.txt",
    noColors:   true,
  },

  paths: {
    sources:   "./contracts",
    tests:     "./test",
    cache:     "./cache",
    artifacts: "./artifacts",
  },
};
