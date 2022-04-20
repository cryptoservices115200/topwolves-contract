const hre = require("hardhat");

async function main() {
  const TopWolves = await hre.ethers.getContractFactory("TopWolves");
  const topWolves = await TopWolves.deploy();

  await topWolves.deployed();

  console.log("TopWolves deployed to:", topWolves.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
