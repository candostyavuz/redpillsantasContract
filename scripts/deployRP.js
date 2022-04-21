
const hre = require("hardhat");
const santa_abi = require('../rps_abi.json')
const gainz_abi = require('../gainz_abi.json')

async function main() {

  let baseURI_RP = "ipfs://QmS2Cj7Y7974Q9sU7nq6WdAxYpLioeEQXHayiMeNTmxvPT/"
  let SANTA_CONTRACT = "0x29Ec00ae5d2948f5237C80a29F3656416D527E4c"
  let GAINZ_CONTRACT = "0xb6c29d3f177022b4E8b3AA786020DD0429D78380"

  // RED PILL CONTRACT

  const signer = new ethers.Wallet(
    process.env.PRIVATE_KEY,
    providers.getDefaultProvider('fuji')
 );

  const santa_contract = new ethers.Contract(SANTA_CONTRACT, santa_abi, signer);
  const gainz_contract = new ethers.Contract(GAINZ_CONTRACT, gainz_abi, signer);

  const RedPill = await hre.ethers.getContractFactory("RedPill");
  const redpill = await RedPill.deploy(santa_contract.address, gainz_contract.address, baseURI_RP);

  await redpill.deployed();

  console.log("RedPill deployed to:", redpill.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
