
const hre = require("hardhat");
const santa_abi = require('../rps_abi.json')
const gainz_abi = require('../gainz_abi.json');
const { ethers } = require("hardhat");

async function main() {

  let baseURI_RP = "ipfs://QmS2Cj7Y7974Q9sU7nq6WdAxYpLioeEQXHayiMeNTmxvPT/"
  let SANTA_CONTRACT = "0x29Ec00ae5d2948f5237C80a29F3656416D527E4c"
  let GAINZ_CONTRACT = "0xb6c29d3f177022b4E8b3AA786020DD0429D78380"

  let deployer = "0x7f6bD981aEA0646771ff2e1F9B642E3C7F9e7741";
  const nonce = await ethers.provider.getTransactionCount(deployer);
  console.log("nonce is:" + nonce);

  const addr1 = ethers.utils.getContractAddress({from: deployer, nonce: nonce - 4});
  console.log("addr-1 is:" + addr1);

  const addr2 = ethers.utils.getContractAddress({from: deployer, nonce: nonce - 3});
  console.log("addr-2 is:" + addr2);

  const RedPill = await hre.ethers.getContractFactory("RedPill");
  const redpill = await RedPill.deploy(addr1, addr2, baseURI_RP);

  await redpill.deployed();

  console.log("RedPill deployed to:", redpill.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
