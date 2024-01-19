import {
  BaalAndVaultSummoner,
  defaultDAOSettings,
  NewBaalParams,
  SHAMAN_PERMISSIONS,
  SetupUsersParams,
  baalSetup,
  setupUsersDefault,
} from "@daohaus/baal-contracts";
import { ethers, getChainId, getNamedAccounts } from "hardhat";

import { ERC6551Registry, FixedLoot, FixedLootShamanSummoner, MintableNFT, NFT6551ClaimerShaman } from "../../types";
import { shouldSummonASuperBaal } from "./ClaimSummoner.behavior";
import { encodeMockClaimShamanParams, setUpNftand6551, summonBaal } from "./ClaimSummoner.fixture";

describe("ClaimSummoner", function () {
  describe("Summoner", function () {
    let baalVaultSummoner: BaalAndVaultSummoner;
    let shamanAddress = "";
    let sidecarVault = "";
    let nftAddress = "";
    let erc6551RegAddress = "";
    let erc655tbaimpAddress = "";
    let erc655tbaproxyAddress = "";

    let summoner: FixedLootShamanSummoner;

    beforeEach(async function () {
      const { deployer } = await getNamedAccounts();

      const { Baal, Loot, Shares, MultiSend, DAI, signers, helpers } = await baalSetup({
        daoSettings: {
          ...defaultDAOSettings, // You can override dao settings
        },
        fixtureTags: [
          "BaalAndVaultSummoner",
          "FixedLootShamanSummoner",
          "FixedLoot",
          "MocksClaim",
          "MocksNFT",
          "MocksTbaReg",
        ],

        setupBaalOverride: async (params: NewBaalParams) => {
          console.log("OVERRIDE baal setup ******");
          baalVaultSummoner = (await ethers.getContract("BaalAndVaultSummoner")) as BaalAndVaultSummoner;
          const fixedLootShamanSummoner = (await ethers.getContract(
            "FixedLootShamanSummoner",
          )) as FixedLootShamanSummoner;
          const fixedTokenSingletonAddress = (await ethers.getContract("FixedLoot")).address;
          console.log(">>>>fixedTokenSingletonAddress", fixedTokenSingletonAddress);
          const sharesTokenSingletonAddress = (await ethers.getContract("Shares")).address;
          console.log(">>>>sharesTokenSingletonAddress", sharesTokenSingletonAddress);
          const mockShamanSingleton = (await ethers.getContract(
            "NFT6551ClaimerShaman",
            deployer,
          )) as NFT6551ClaimerShaman;
          console.log(">>>mockShamanSingleton", mockShamanSingleton.address);

          const { baalSingleton, poster, config, adminConfig } = params;

          const nftAndReg = await setUpNftand6551();
          nftAddress = nftAndReg.nft;
          erc6551RegAddress = nftAndReg.ERC6551Reg;

          console.log(">>>nft", nftAddress);
          console.log(">>>ERC6551Reg", erc6551RegAddress);

          const newBaalAddresses = await summonBaal({
            summoner: fixedLootShamanSummoner,
            baalSingleton,
            poster,
            config,
            adminConfig,
            shamans: undefined,
            lootConfig: {
              name: "Fixed Loot",
              symbol: "FLOOT",
              initialHolders: [], //
              initialAmounts: [
                ethers.utils.parseEther("200000").toString(), // vault
                ethers.utils.parseEther("100000").toString(), // shaman
              ],
              singletonAddress: fixedTokenSingletonAddress,
            },
            sharesConfig: {
              name: "Standard Shares",
              symbol: "SHARES",
              singletonAddress: sharesTokenSingletonAddress,
            },
            shamanConfig: {
              permissions: [SHAMAN_PERMISSIONS.MANAGER],
              setupParams: [encodeMockClaimShamanParams(nftAddress, erc6551RegAddress, ethers.constants.AddressZero, ethers.constants.AddressZero)],
              singletonAddress: [mockShamanSingleton.address],
            },
          });
          shamanAddress = newBaalAddresses.shaman;
          sidecarVault = newBaalAddresses.sidecarVault;
          summoner = fixedLootShamanSummoner;

          return newBaalAddresses;
        },
        setupUsersOverride: async (params: SetupUsersParams) => {
          console.log("OVERRIDE Users setup ******", params.addresses);
          return setupUsersDefault(params);
        },
      });

      this.helpers = helpers; // helper functions use the same daoSettings used during setup
      this.baalVaultSummoner = baalVaultSummoner;
      this.summoner = summoner;
      this.deployer = deployer;
      this.baal = Baal;
      this.loot = Loot;
      this.shares = Shares;
      this.multisend = MultiSend;
      this.dai = DAI;
      this.users = signers;
      this.chainId = await getChainId();
      this.fixedLoot = (await ethers.getContractAt("FixedLoot", this.loot.address, deployer)) as FixedLoot;

      this.shaman = (await ethers.getContractAt(
        "NFT6551ClaimerShaman",
        shamanAddress,
        deployer,
      )) as NFT6551ClaimerShaman;
      this.sidecarVaultAddress = sidecarVault;
      this.nft = (await ethers.getContractAt("MintableNFT", nftAddress, deployer)) as MintableNFT;
      this.registry = (await ethers.getContractAt("ERC6551Registry", erc6551RegAddress, deployer)) as ERC6551Registry;
    });

    shouldSummonASuperBaal();
  });
});
