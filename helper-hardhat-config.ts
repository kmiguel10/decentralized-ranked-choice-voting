export interface networkConfigItem {
    ethUsdPriceFeed?: string
    blockConfirmations?: number
}

export interface networkConfigInfo {
    [key: string]: networkConfigItem
}

export const networkConfig: networkConfigInfo = {
    localhost: {},
    hardhat: {},
    // Price Feed Address, values can be obtained at https://docs.chain.link/docs/reference-contracts
    // Default one is ETH/USD contract on Kovan
    goerli: {
        blockConfirmations: 6,
    },
}

export const developmentChains = ["hardhat", "localhost"]
export const VERIFICATION_BLOCK_CONFIRMATIONS = 6
//export const frontEndContractsFile =
;("../bounty-dapp-frontend/constants/networkMapping.json")
// export const frontEndContractsFile2 =
//     "../nextjs-nft-marketplace-thegraph-fcc/constants/networkMapping.json"
//export const frontEndAbiLocation = "../bounty-dapp-frontend/constants/"
// export const frontEndAbiLocation2 =
//     "../nextjs-nft-marketplace-thegraph-fcc/constants/"
