import { getSetupAddresses } from "@daohaus/baal-contracts";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { deploymentConfig } from "../constants";

const deployFn: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { getChainId, deployments, network } = hre;
  const { deployer } = await hre.getNamedAccounts();

  console.log("\nDeploying NFTCurator factory on network:", network.name);

  const chainId = await getChainId();
  const setupAddresses = await getSetupAddresses(chainId, network, deployments);
  console.log("setupAddresses", setupAddresses);
  const addresses = deploymentConfig[chainId];

  if (network.name !== "hardhat") {
    if (!addresses?.baalSummoner) throw Error("No address found for BaalSummoner");
    console.log(`Re-using contracts on ${network.name}:`);
    console.log("BaalSummoner", addresses.baalSummoner);
  }

  const summonerAddress =
    network.name === "hardhat" ? (await deployments.get("BaalSummoner")).address : addresses.baalSummoner;

  const hosSummonerDeployed = await deployments.deploy("NFTCuratorShamanSummoner", {
    contract: "NFTCuratorShamanSummoner",
    from: deployer,
    args: [],
    proxy: {
      proxyContract: "UUPS",
      execute: {
        methodName: "initialize",
        args: [summonerAddress, setupAddresses.moduleProxyFactory],
      },
    },
    log: true,
  });
  console.log("NFTCurator deployment Tx ->", hosSummonerDeployed.transactionHash);

  // const owner = addresses?.owner || deployer;
  // console.log("NFTCurator transferOwnership to", owner);
  // const txOwnership = await hre.deployments.execute(
  //   "NFTCurator",
  //   {
  //     from: deployer,
  //   },
  //   "transferOwnership",
  //   owner,
  // );
  // console.log("NFTCurator transferOwnership Tx ->", txOwnership.transactionHash);

  // if (network.name !== "hardhat" && owner !== deployer && !addresses?.baalSummoner) {
  //   console.log("baalSummoner transferOwnership to", owner);
  //   const tx = await deployments.execute(
  //     "BaalSummoner",
  //     {
  //       from: deployer,
  //     },
  //     "transferOwnership",
  //     owner,
  //   );
  //   console.log("BaalAndVaultSummoner transferOwnership Tx ->", tx.transactionHash);
  // }
};

export default deployFn;
deployFn.id = "012_deploy_NFTCuratorSummoner"; // id required to prevent reexecution
deployFn.tags = ["Factories", "NFTCuratorSummoner"];
