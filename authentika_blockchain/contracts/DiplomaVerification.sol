// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DiplomaVerification {

    struct Diploma {
        string studentName;
        string diplomaHash;
        bool isValid;
    }

    mapping(string => Diploma) public diplomas;

    // Fonction pour ajouter un diplôme à la blockchain
    function addDiploma(string memory _studentName, string memory _diplomaHash) public {
        diplomas[_diplomaHash] = Diploma(_studentName, _diplomaHash, true);
    }

    // Fonction pour vérifier si un diplôme est valide
    function verifyDiploma(string memory _diplomaHash) public view returns (bool) {
        return diplomas[_diplomaHash].isValid;
    }

    // Fonction pour révoquer un diplôme
    function revokeDiploma(string memory _diplomaHash) public {
        diplomas[_diplomaHash].isValid = false;
    }
}
