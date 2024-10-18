import 'package:http/http.dart'; // Import pour les requêtes HTTP
import 'package:web3dart/web3dart.dart'; // Import pour interagir avec la blockchain
import 'dart:developer'; // Import pour utiliser les logs

class BlockchainService {
  final String rpcUrl = "http://127.0.0.1:8545"; // URL de Ganache
  final String contractAddress =
      "0x1234567890abcdef1234567890abcdef12345678"; // Remplace par l'adresse du contrat
  final String privateKey =
      "e9d420794eea2f55363f9fbbd34458f91842f5cd680e638ac2e80e76f6a54af5"; // Clé privée d'un compte Ganache
  late Web3Client client;
  late Credentials credentials;

  BlockchainService() {
    client = Web3Client(rpcUrl, Client());
    credentials = EthPrivateKey.fromHex(privateKey);
  }

  // Fonction pour vérifier un diplôme avec des logs
  Future<bool> verifyDiploma(String diplomaHash) async {
    try {
      log("Connexion au client Web3 via $rpcUrl...");

      final contract = DeployedContract(
        ContractAbi.fromJson(abiCode, "DiplomaVerification"),
        EthereumAddress.fromHex(contractAddress),
      );

      log("Contrat trouvé à l'adresse $contractAddress");

      final verifyFunction = contract.function("verifyDiploma");

      log("Appel de la fonction 'verifyDiploma' avec le hash: $diplomaHash...");

      final result = await client.call(
        contract: contract,
        function: verifyFunction,
        params: [diplomaHash],
      );

      log("Résultat de la blockchain : ${result.first}");

      return result.first as bool;
    } catch (e) {
      log("Erreur lors de la vérification du diplôme : $e");
      rethrow; // Propager l'erreur pour qu'elle soit visible dans Flutter
    }
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
