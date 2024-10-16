module.exports = {
  networks: {
    // Configuration pour Ganache (port 8545)
    development: {
      host: "127.0.0.1",  // Adresse locale pour Ganache
      port: 8546,         // Port utilisé par Ganache CLI
      network_id: "*",    // Accepte toutes les versions du réseau (network id)
    },
  },

  // Configuration du compilateur Solidity
  compilers: {
    solc: {
      version: "0.8.21",   // Version exacte de Solidity utilisée
    }
  },

  // Configuration Mocha (tests)
  mocha: {
    // timeout: 100000     // Tu peux ajuster les options si tu utilises Mocha pour les tests
  },

  // Truffle DB (désactivée par défaut)
  db: {
    enabled: false,
  }
};
