
const hre = require("hardhat");

async function main() {

  let baseURI = "ipfs://QmUBkWy23dRTb5UUSi6qn6mpApxmj88a1RP9AYstrUtaJv/";
  let baseURI_RP = "ipfs://QmUMrcqoLDsEPrZY3qYD43Rqid3eyAeXQRFjc8B5UXBVv7/"
  let admin1 = "0xb70A69CaF32786C68C5a8D489Efd8b1056f242D0";
  let admin2 = "0x3EC0a5C399ACEEFEC2dda402a4435fF1085146E1";
  let admin3 = "0x44Fc5557bA608F32C721F4f1216bB99943c8cD84";
  let prizeWallet = "0x8E8A40D012872A6E6bf2D888DD6cD5C5F06a9c69";

  const owner = await ethers.provider.getSigner(admin1);

  // RPS CONTRACT
  const RedPillSantas = await hre.ethers.getContractFactory("RedPillSanta");
  const redpillsantas = await RedPillSantas.deploy(baseURI, admin1, admin2, admin3, prizeWallet);

  await redpillsantas.deployed();

  console.log("RedPillSantas deployed to:", redpillsantas.address);

  // GAINZ CONTRACT
  const Gainz = await hre.ethers.getContractFactory("Gainz");
  const gainz = await Gainz.deploy(redpillsantas.address);

  await gainz.deployed();

  console.log("Gainz deployed to:", gainz.address);

  // authorize gainz contract on santa contract
  const santaContract = await hre.ethers.getContractAt("RedPillSanta", redpillsantas.address);
  const transaction = await santaContract.connect(owner).addAuthorized(gainz.address);
  await transaction.wait();
  console.log("gainz contract is authorized on santa contract! ");

  // RED PILL CONTRACT
  const RedPill = await hre.ethers.getContractFactory("RedPill");
  const redpill = await RedPill.deploy(redpillsantas.address, gainz.address, baseURI_RP);

  await redpill.deployed();

  console.log("RedPill deployed to:", redpill.address);

  // authorize redpill contract on gainz contract
  const gainzContract = await hre.ethers.getContractAt("Gainz", gainz.address);
  const transaction2 = await gainzContract.connect(owner).addAuthorized(redpill.address);
  await transaction2.wait();
  console.log("redpill contract is authorized on gainz contract! ");

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
