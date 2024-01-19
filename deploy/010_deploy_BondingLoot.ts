import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFn: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, network } = hre;
  const { deployer } = await hre.getNamedAccounts();

  console.log("\nDeploying BondingLoot singleton on network:", network.name);

  const governorLootDeployed = await deployments.deploy("BondingLoot", {
    contract: "BondingLoot",
    from: deployer,
    args: [],
    // proxy: {
    //     proxyContract: 'UUPS',
    //     methodName: 'initialize',
    // },
    log: true,
  });
  console.log("BondingLoot deployment Tx ->", governorLootDeployed.transactionHash);
};

export default deployFn;
deployFn.id = "010_deploy_BondingLoot"; // id required to prevent reexecution
deployFn.tags = ["Factories", "BondingLoot"];
