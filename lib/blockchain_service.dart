import 'package:http/http.dart'; // Pour les requêtes HTTP
import 'package:web3dart/web3dart.dart'; // Pour interagir avec la blockchain

class BlockchainService {
  final String rpcUrl =
      "http://127.0.0.1:8545"; // URL de Ganache (ajuste si Ganache est sur un autre port)
  final String contractAddress =
      "TON_ADRESSE_CONTRAT"; // Remplace par l'adresse du contrat déployé
  final String privateKey =
      "0xf7cfa74ebdce0a3d6932724fd6a3168f307315282a749a4c9a82124d3787a69f"; // Remplace par la clé privée d'un compte Ganache
  late Web3Client client;
  late Credentials credentials;

  BlockchainService() {
    client = Web3Client(rpcUrl, Client());
    credentials = EthPrivateKey.fromHex(privateKey);
  }

  // Fonction pour vérifier un diplôme
  Future<bool> verifyDiploma(String diplomaHash) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(abiCode, "DiplomaVerification"),
      EthereumAddress.fromHex(contractAddress),
    );

    final verifyFunction = contract.function("verifyDiploma");

    final result = await client.call(
      contract: contract,
      function: verifyFunction,
      params: [diplomaHash],
    );

    return result.first as bool;
  }

  // Code ABI du contrat
  String abiCode = '''[
    {
      "constant": true,
      "inputs": [{"name": "_diplomaHash", "type": "string"}],
      "name": "verifyDiploma",
      "outputs": [{"name": "", "type": "bool"}],
      "type": "function"
    }
  ]''';
}
