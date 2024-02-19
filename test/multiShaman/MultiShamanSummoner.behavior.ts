import { Baal, IBaal, IBaalToken, SHAMAN_PERMISSIONS, encodeMultiAction } from "@daohaus/baal-contracts";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";

import { CommunityVetoShaman, SimpleEthOnboarderShaman } from "../../types";

export function shouldSummonASuperBaal(): void {
  it("Should have a manager shaman and a governor shaman", async function () {
    expect(this.shaman?.address.length).greaterThan(0);
    expect(await (this.baal as IBaal).shamans(this.shaman.address)).to.equal(SHAMAN_PERMISSIONS.MANAGER);
    expect(await (this.baal as IBaal).shamans(this.vetoShaman.address)).to.equal(SHAMAN_PERMISSIONS.GOVERNANCE);
  });

  it("Should have shares and loot", async function () {
    const sharesSymbol = await (this.shares as IBaalToken).symbol();
    const lootSymbol = await (this.loot as IBaalToken).symbol();

    const baalShares = await (this.baal as IBaal).sharesToken();
    const baalLoot = await (this.baal as IBaal).lootToken();

    expect(sharesSymbol).to.equal("SHARES");
    expect(lootSymbol).to.equal("GLOOT");
    expect(baalShares).to.equal(this.shares.address);
    expect(baalLoot).to.equal(this.loot.address);
  });

  it("Should have loot,shares ownership with baal", async function () {
    const sharesOwner = await (this.shares as IBaalToken).owner();
    const lootOwner = await (this.loot as IBaalToken).owner();
    expect(sharesOwner).to.equal(this.baal.address);
    expect(lootOwner).to.equal(this.baal.address);
  });

  it("Should mint shares", async function () {
    const s1Balance = await (this.shares as IBaalToken).balanceOf(this.unnamedUsers[0]);
    expect(s1Balance).to.equal(this.amounts[0]);
  });

  it("Should mint loot", async function () {
    const l1Balance = await (this.loot as IBaalToken).balanceOf(this.unnamedUsers[0]);
    expect(l1Balance).to.equal(this.amounts[0]);
  });

  it("should be initialized", async function () {
    const init = this.summoner?.initialize(ethers.constants.AddressZero, ethers.constants.AddressZero);
    await expect(init).to.be.revertedWith("Initializable: contract is already initialized");
  });
}

export function shouldHaveCommunityVetoPower(): void {
  it.skip("Should be able to cancel a proposal after dissenters threshold", async function () {
    //todo: break this up into multiple tests
    // get some addresss
    const [s1, s2] = await ethers.getSigners();
    console.log("s1", s1.address);
    console.log("s2", s2.address);

    // connect s1 to onboarder shaman
    const shamanAsS1 = (await ethers.getContractAt(
      "SimpleEthOnboarderShaman",
      this.shaman.address,
      s1.address,
    )) as SimpleEthOnboarderShaman;

    // onboard s1, sending eth returns shares
    await shamanAsS1.onboarder({ value: ethers.utils.parseEther("1") });
    // const totalSharesBalance = await this.shares.totalSupply();
    // console.log("totalSharesBalance", totalSharesBalance.toString());
    // const sharesBalance = await this.shares.balanceOf(s1.address);
    // console.log("sharesBalance s1", sharesBalance.toString());
    // expect shares to equal eth times multiply

    // connect s2 to baal and community veto shaman
    const baalAsS1 = (await ethers.getContractAt("Baal", this.baal.address, s1.address)) as Baal;
    const shamanAsS2 = (await ethers.getContractAt(
      "CommunityVetoShaman",
      this.vetoShaman.address,
      s2.address,
    )) as CommunityVetoShaman;

    // mint loot to s2 with proposal from s1
    const mintLoot = await this.baal.interface.encodeFunctionData("mintLoot", [
      [s2.address],
      [ethers.utils.parseEther("69")],
    ]);
    const encodedLootAction = encodeMultiAction(
      this.multisend,
      [mintLoot],
      [this.baal.address],
      [BigNumber.from(0)],
      [0],
    );

    await this.helpers.submitAndProcessProposal({
      baal: baalAsS1, // deployer is the only account with shares
      encodedAction: encodedLootAction,
      proposal: {
        flag: 1,
        account: ethers.constants.AddressZero,
        data: "",
        details: "",
        expiration: 0,
        baalGas: 0,
      },
      extraSeconds: 3, // # extra blocks to wait before processing the proposal
    });

    // const lootBalance = await this.loot.balanceOf(s2.address);
    // console.log("lootBalance s2", lootBalance.toString());
    // expect loot to equal 69 for s2

    // set up proposal to be vetod
    const mintShares = await this.baal.interface.encodeFunctionData("mintShares", [
      [this.users.summoner.address],
      [ethers.utils.parseEther("69")],
    ]);
    const encodedAction = encodeMultiAction(
      this.multisend,
      [mintShares],
      [this.baal.address],
      [BigNumber.from(0)],
      [0],
    );
    await baalAsS1.submitProposal(encodedAction, 0, 0, ""); // deployer is the only account with shares
    const id = await this.baal.proposalCount();
    await baalAsS1.submitVote(id, true);

    // s2 stakes against proposal, should hit small initial threshold
    await shamanAsS2.initAndStakeVeto(id, "neg");
    // anyone can now cancel proposal
    await (this.vetoShaman as CommunityVetoShaman).cancelProposal(id);
    const ps = await (this.baal as Baal).getProposalStatus(id);
    // expect proposal to be cancelled
    expect(ps).to.eql([true, false, false, false]);
  });
}
