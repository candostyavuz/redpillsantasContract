
const hre = require("hardhat");

async function main() {

  let baseURI = "ipfs://QmUBkWy23dRTb5UUSi6qn6mpApxmj88a1RP9AYstrUtaJv/";
  let baseURI_RP = "ipfs://QmUMrcqoLDsEPrZY3qYD43Rqid3eyAeXQRFjc8B5UXBVv7/"
  let admin1 = "0xb4d2dfE07DF99959Cd2EdB98aab8455c69b612aA";
  let admin2 = "0x7f6bD981aEA0646771ff2e1F9B642E3C7F9e7741";
  let admin3 = "0x212c8469e64811B3c1D478a2176C17Aa58166E51";
  let prizeWallet = "0x4E97B551cF67d0162C2fFCAF3C0dc18Eed550AaF";

  const owner = await ethers.provider.getSigner("0xb4d2dfE07DF99959Cd2EdB98aab8455c69b612aA");

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
