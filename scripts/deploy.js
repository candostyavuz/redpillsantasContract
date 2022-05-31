
const hre = require("hardhat");

async function main() {

  let baseURI = "ipfs://QmUBkWy23dRTb5UUSi6qn6mpApxmj88a1RP9AYstrUtaJv/";
  let baseURI_RP = "ipfs://QmUMrcqoLDsEPrZY3qYD43Rqid3eyAeXQRFjc8B5UXBVv7/"
  let admin1 = "0x8606aca0733Cd2D23638aC1b80534Bf13633fb2A";
  let admin2 = "0x94Bb8EA39921e21bEa9ff855058c8fdb153A99F7";
  let admin3 = "0xC62aafc8Cd26560A8133Dc9663E738A6C667e0FA";
  let prizeWallet = "0x57681971DC7D8F4F9751923b7215E7eb1Df1A9cb";

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
