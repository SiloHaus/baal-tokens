import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFn: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, network } = hre;
  const { deployer } = await hre.getNamedAccounts();

  console.log("\nDeploying NFTCuratorShaman singleton on network:", network.name);
  console.log("\nDeploying from address", deployer);

  const nftShamanDeployed = await deployments.deploy("NFTCuratorShaman", {
    contract: "NFTCuratorShaman",
    from: deployer,
    args: [],
    // proxy: {
    //     proxyContract: 'UUPS',
    //     methodName: 'initialize',
    // },
    log: true,
  });
  console.log("NFTCuratorShaman deployment Tx ->", nftShamanDeployed.transactionHash);
};

export default deployFn;
deployFn.id = "011_deploy_NFTCuratorShaman"; // id required to prevent reexecution
deployFn.tags = ["NFTCuratorShaman"];
