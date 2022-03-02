
const hre = require("hardhat");

async function main() {

  let baseURI = "ipfs:/";
  let admin1 = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266";
  let admin2 = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";
  let admin3 = "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc";

  const RedPillSantas = await hre.ethers.getContractFactory("RedPillSanta");
  const redpillsantas = await RedPillSantas.deploy(baseURI, admin1, admin2, admin3);

  await redpillsantas.deployed();

  console.log("RedPillSantas deployed to:", redpillsantas.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
