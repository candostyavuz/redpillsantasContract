const { ethers } = require("hardhat");
const redPillAddress = "0x289CF1a2980980a312cFedc47841c70E53dEe802"

const addresses = [
    "0xC920158ed2D84b311f11963485207C12D18F02Cf",
    "0x4f2503e23De24bF6B9683A355853E1D1B97a6127",
    "0x585FF2a99a6c459d7209c065E4906B5D525bcEE0",
    "0x4f2503e23De24bF6B9683A355853E1D1B97a6127",
    "0x53Dc459E24d86197C8c88D651546e96C00Bbe53d",
    "0x6963E9103ca631bea8dcDa9f7BB6d5f8c77dbE30",
    "0x5db4c4D089C1dc91D4d7213ADb1863870Bc08c08",
    "0xbe8f2088a1b6B6aBeF9a693100768e2cBb0D367c",
    "0x28079dAb0E00338d11b5c0E5f693cD0Ab93b8b00",
    "0xE667584fC60338098294D408efceEB3EcC6d79D1",
    "0xb5EB9d314716Fb533dB7d9886dbd1Ab58Ad6973E",
    "0x6963E9103ca631bea8dcDa9f7BB6d5f8c77dbE30",
    "0x5007B53757858b7C378Dd109BaEED2a35df3fAe6",
    "0x8B1Ab082f74B46c1D41d52d1f561258e3535f8Fa",
    "0xb5EB9d314716Fb533dB7d9886dbd1Ab58Ad6973E",
    "0xb4d2dfE07DF99959Cd2EdB98aab8455c69b612aA"
]

async function main() {
    const owner = await ethers.provider.getSigner("0xb4d2dfE07DF99959Cd2EdB98aab8455c69b612aA");
    const rpContract = await hre.ethers.getContractAt("RedPill", redPillAddress);

    for(let i = 0; i <addresses.length; i++) {
        let count = addresses.filter(x => x == addresses[i]).length;
        const transaction = await rpContract.connect(owner).airDropRedPill(addresses[i], count);
        await transaction.wait();
        console.log("redpill airdropped to: " + addresses[i])
    }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });