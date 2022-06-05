require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

module.exports = {
	solidity: {
		compilers: [
			{
				version: "0.8.4",
			},
			{
				version: "0.6.4",
			},
		],
	},
	networks: {
		rinkeby: {
			url: process.env.STAGING_ALCHEMY_KEY,
			accounts: [process.env.PRIVATE_KEY],
		},
	},
};
