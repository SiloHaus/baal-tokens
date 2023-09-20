import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { deploymentConfig } from "../constants";

const deployFn: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getChainId, deployments, network } = hre;
  const { deployer } = await hre.getNamedAccounts();

  console.log("\nDeploying FixedLootShamanSummoner factory on network:", network.name);

  const chainId = await getChainId();
  // const _addresses = await getSetupAddresses(chainId, network, deployments);
  const addresses = deploymentConfig[chainId];

  if (network.name !== "hardhat") {
    if (!addresses?.bvSummoner) throw Error("No address found for BaalAndVaultSummoner");
    console.log(`Re-using contracts on ${network.name}:`);
    console.log("BaalAndVaultSummoner", addresses.bvSummoner);
  }

  const bvSummonerAddress =
    network.name === "hardhat" ? (await deployments.get("BaalAndVaultSummoner")).address : addresses.bvSummoner;
  // TODO: this should be retrieved from getSetupAddresses
  const moduleProxyFactoryAddress = 
    network.name === "hardhat"
      ? (await deployments.get("ModuleProxyFactory")).address
      : "0x00000000000DC7F163742Eb4aBEf650037b1f588";

  const hosSummonerDeployed = await deployments.deploy("FixedLootShamanSummoner", {
    contract: "FixedLootShamanSummoner",
    from: deployer,
    args: [],
    proxy: {
      proxyContract: "UUPS",
      execute: {
        methodName: "initialize",
        args: [bvSummonerAddress, moduleProxyFactoryAddress],
      },
    },
    log: true,
  });
  console.log("FixedLootShamanSummoner deployment Tx ->", hosSummonerDeployed.transactionHash);

  const owner = addresses?.owner || deployer;
  console.log("FixedLootShamanSummoner transferOwnership to", owner);
  const txOwnership = await hre.deployments.execute(
    "FixedLootShamanSummoner",
    {
      from: deployer,
    },
    "transferOwnership",
    owner,
  );
  console.log("FixedLootShamanSummoner transferOwnership Tx ->", txOwnership.transactionHash);

  if (network.name !== "hardhat" && owner !== deployer && !addresses?.bvSummoner) {
    console.log("BaalAndVaultSummoner transferOwnership to", owner);
    const tx = await deployments.execute(
      "BaalAndVaultSummoner",
      {
        from: deployer,
      },
      "transferOwnership",
      owner,
    );
    console.log("BaalAndVaultSummoner transferOwnership Tx ->", tx.transactionHash);
  }
};

export default deployFn;
deployFn.id = "001_deploy_Summoner"; // id required to prevent reexecution
deployFn.tags = ["Factories", "FixedLootShamanSummoner"];
