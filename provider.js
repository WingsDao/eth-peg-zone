const HDWalletProvider = require("truffle-hdwallet-provider");
const MNEMONIC = process.env.MNEMONIC;

exports.getHDProvider = () => {
  if (!MNEMONIC) {
    throw new Error('to use ropsten, provide MNEMONIC via env, e.g. MNEMONIC=...');
  }

  return new HDWalletProvider(MNEMONIC, "https://ropsten.infura.io/v3/f31e8a625c21459ab430f19e3eede240")
}
