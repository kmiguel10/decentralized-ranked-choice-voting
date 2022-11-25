import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"

import "@typechain/hardhat"
import "@nomiclabs/hardhat-ethers"
import "hardhat-deploy"
import "solidity-coverage"
import "dotenv/config"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-ethers"
import "hardhat-gas-reporter"
import "solidity-coverage"
import "@nomiclabs/hardhat-web3"

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || ""
const PRIVATE_KEY = process.env.PRIVATE_KEY || ""
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            //gasPrice: 130_000_000_000,
            gas: "auto",
            // allowUnlimitedContractSize: true,
            // throwOnTransactionFailures: true,
            // throwOnCallFailures: true,
            // allowUnlimitedContractSize: true,
            blockGasLimit: 330_022_488_000,
            //gasMultiplier: 2,
        },
        localhost: { chainId: 31337, gasPrice: 130000000000 },
        goerli: {
            url: GOERLI_RPC_URL,
            accounts: [PRIVATE_KEY],
            chainId: 5,
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    solidity: {
        compilers: [
            {
                version: "0.8.9",
            },
            {
                version: "0.6.6",
            },
        ],
        settings: {
            // optimizer: {
            //     enabled: true,
            //     runs: 200,
            // },
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
    },
    // gasReporter: {
    //     enabled: true,
    // },
    gasReporter: {
        enabled: true,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
        // coinmarketcap: COINMARKETCAP_API_KEY,
    },
}

export default config
