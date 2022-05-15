const { ethers } = require("hardhat");
const redPillSantaAddress = "0x0B063846F79f4310cAB54B784d3301Cb8428Bdda"

const addresses = [
    "0x3A766f2978cFC31Af8a5Ef3A63C3C4842215B3cd",
    "0xA3E97baeb1d848ae560e9D2a30Cc3181aFc2186F",
    "0x3D52b45278e81985Bd5733C645A7A21b0912BBFA",
    "0xE51Ad9C7fD79731ef88Ec82B4fcdC549f0ff50df",
    "0x0F5aBF9053b21e43C1cD0065A7E0f1eA3CfddA14",
    "0x575A4d579f965e2575026A576E64d54f14130EC8",
    "0x13FC5c606A41A9A7A8BA4fa369545238448ce175",
    "0xC9140a44D16a6e5Abb318493b1212dbAb8B68266",
    "0x0aA1EF1553bbC320D6860E80FD03fD9B0556190A",
    "0xd2c40f1dB0D6D31b66d2859380E759c78eeF8690",
    "0xC8fDABC048BA7f9491C12eb77dC6F707fe528bAA",
    "0xBF5F7c896C8ED425a333ad3BD8c2A49937286b1A",
    "0x90422Bca8BB6545eC81dD4545bb8e1bE6878f43E",
    "0x320f95638111F6D879E54C61599dB42E2571D7d7",
    "0x0DD39084c55e403E80e50259243AEf43dbe6A9ee",
    "0x7024eE7932E4d879409F9618b560Cc82CF093a7a",
    "0xd68ac712b51134ea3faDF39E03F707C06e6FA94d",
    "0x821D3fA2b4DD591f241b3BEe0f3701dc302a8979",
    "0xde52A744E041e65564A18731bc47bb40c066677A",
    "0x95191D2da6ADFad8b12472673F11CB9042C3B398",
    "0x7C3D005760621b4fe61D94eE37D45878c9CEffc9",
    "0x513df82b8f4E8719B94BE54f6a0A6FdC0beDA33A",
    "0xA61b6361ACc46D460257962750aB2780a789a0f4",
    "0x51d3516465b8e3ebb73f4d1a42c75c9b32f85449",
    "0xc9BFEA95d02961EA9ea77c3B889AdA773FBc1cc2",
    "0xD776F1bB4B6e1F4522B6a8BAE7bdfc179EA12cd0",
    "0x86a85FFc0b4A576f42Ca642dDdf4EF635bC35257",
    "0x1912294E9C311dD806D1BCe53AD58eAafd36C9Ce",
    "0xA9884661b9707BDF73dEC59e72Db75616336da06",
    "0xA2c4F8Ad1092cC550A6D40B04cB8Be7e32E3ba7C",
    "0x8dfDD509f7537713f68FD64Bf98F1E246482e8da",
    "0xD6Bf39a0E887187f5DB2DeB3c43a1BA023f3a2E3",
    "0x5103dCB3A7364dAC5919bfe377547536A64101F0",
    "0x13495F70d05fe53DAc88193175ecbdFE82cbBB40",
    "0x2049952B1c1218a400664D4bC54F4FF77a59b6a8",
    "0x6e8A89b8106B1d0180ED4Ddc1E04b56936442Dc5",
    "0x2cB4d5f92a5164A62874F8D7f85984AF71E9693B",
    "0x81978e9a08f8375efa3C57bacE13d71739C0c4B0",
    "0xe7980C283E450A0a48e9B6Da34eeA8d287Bb3BF3",
    "0x45b6aC5CAEB044725e4974cEeBf66dFe522Ccc90",
    "0x28079dAb0E00338d11b5c0E5f693cD0Ab93b8b00",
    "0x63731d2f56c8637e500958Ef65EF26A604f2771f",
    "0xCD46A9daDF5428199E06229d5c15A68EBdF865F5",
    "0x63C4099EE810B018be88D01d6B6bfE950F13a615",
    "0x8C4C8CCcDb2ece9dd5aa0E2129C7784788f4e923",
    "0x87B0DF8dFeF2deFbA32d327483ADc0366ae74b8F",
    "0x468b5Bc120E21caD823B7A09BEa0BAf3845ECaCA",
    "0xe1b1FDD80de3151e392f27CD5D161F793bCF7952"
]

async function main() {

    const owner = await ethers.provider.getSigner("0xb4d2dfE07DF99959Cd2EdB98aab8455c69b612aA");

    const santaContract = await hre.ethers.getContractAt("RedPillSanta", redPillSantaAddress);

    await santaContract.connect(owner).setWhitelist(addresses);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });