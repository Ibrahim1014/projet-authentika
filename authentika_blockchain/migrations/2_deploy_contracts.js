const DiplomaVerification = artifacts.require("DiplomaVerification");

module.exports = function (deployer) {
  deployer.deploy(DiplomaVerification);
};
