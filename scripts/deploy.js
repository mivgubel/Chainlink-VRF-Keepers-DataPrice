async function main() {
	// We get the contract to deploy.
	const bullBearfactory = await hre.ethers.getContractFactory("BullBear");
	const bullBearContract = await bullBearfactory.deploy(15, 5686);
	await bullBearContract.deployed();

	console.log("bullBear deployed to:", bullBearContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.log(error);
		process.exit(1);
	});
