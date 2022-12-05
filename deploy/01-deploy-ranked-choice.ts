import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../utils/verify"
import {
    networkConfig,
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
} from "../helper-hardhat-config"

const deployRankedChoiceContract: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    // @ts-ignore
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId!
    const args: any[] = []
    const waitBlockConfirmations = developmentChains.includes(network.name)
        ? 1
        : VERIFICATION_BLOCK_CONFIRMATIONS

    log("--------------------------------------------")
    log("deploying RankedChoiceContract and waiting for confirmations...")
    log(`deployer is ${deployer}`)
    log(`chainId is ${chainId}`)

    const rankedChoiceContract = await deploy("RankedChoiceContract", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: waitBlockConfirmations,
    })

    log(`RankedChoiceContract deployed at ${rankedChoiceContract.address}`)

    if (chainId !== 31337 && process.env.ETHERSCAN_API_KEY) {
        await verify(rankedChoiceContract.address, [])
    }
}

export default deployRankedChoiceContract
deployRankedChoiceContract.tags = ["all", "rankedChoiceContract"]
