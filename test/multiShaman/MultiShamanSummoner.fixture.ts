import { ethers } from "hardhat";

export const abiCoder = ethers.utils.defaultAbiCoder;

export const encodeMockVetoShamanParams = function () {
  const threshold = 100;

  const shamanParams = abiCoder.encode(["uint256"], [threshold]);
  return shamanParams;
};

export const encodeNFTCuratorShamanParams = function () {
  const shamanParams = abiCoder.encode(
    ["string", "string", "uint256", "uint256", "uint256", "uint256", "address", "string"],
    [
      "test",
      "TOK",
      "1000000000000000000",
      "1000000000000000000",
      "42000000000000",
      "5",
      "0xCED608Aa29bB92185D9b6340Adcbfa263DAe075b",
      "test",
    ],
  );

  return shamanParams;
};
