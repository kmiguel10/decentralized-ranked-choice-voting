import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../utils/verify"
import { networkConfig, developmentChains } from "../helper-hardhat-config"

const deployRankedChoiceContract: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    // @ts-ignore
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId!

    log("--------------------------------------------")
    log("deploying RankedChoiceContract and waiting for confirmations...")

    const rankedChoiceContract = await deploy("RankedChoiceContract", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: networkConfig[network.name].blockConfirmations || 0,
    })

    log(`RankedChoiceContract deployed at ${rankedChoiceContract.address}`)

    if (chainId !== 31337 && process.env.ETHERSCAN_API_KEY) {
        await verify(rankedChoiceContract.address, [])
    }
}

export default deployRankedChoiceContract
deployRankedChoiceContract.tags = ["all", "rankedChoiceContract"]
