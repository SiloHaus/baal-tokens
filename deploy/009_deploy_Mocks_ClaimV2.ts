import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFn: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, network } = hre;
  const { deployer } = await hre.getNamedAccounts();

  console.log("\nDeploying NFT6551ClaimerShamanV2 mock on network:", network.name);

  const shamanDeployed = await deployments.deploy("NFT6551ClaimerShamanV2", {
    contract: "NFT6551ClaimerShamanV2",
    from: deployer,
    args: [],
    // proxy: {
    //     proxyContract: 'UUPS',
    //     methodName: 'initialize',
    // },
    log: true,
  });
  console.log("NFT6551ClaimerShamanV2 deployment Tx ->", shamanDeployed.transactionHash);
};

export default deployFn;
deployFn.id = "009_deploy_Mocks_ClaimV2"; // id required to prevent reexecution
deployFn.tags = ["MocksClaimV2"];
