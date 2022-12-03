import { GetContractTypeFromFactory } from "./../typechain-types/common"
import { RankedChoiceContract } from "./../typechain-types/RankedChoiceContract"
const { ethers, network } = require("hardhat")
const { moveBlocks } = require("../utils/move-blocks")

async function registerCandidates() {
    console.log("TEST")
}

registerCandidates()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error)
        process.exit(1)
    })
