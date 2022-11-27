import { network } from "hardhat"

export function sleep(timeInMs: number | undefined) {
    return new Promise((resolve) => setTimeout(resolve, timeInMs))
}

export async function moveBlocks(amount: number, sleepAmount = 0) {
    console.log("moving blocks. . . . . ")
    for (let index = 0; index < amount; index++) {
        await network.provider.request({
            method: "evm_mine",
            params: [],
        })
        if (sleepAmount) {
            console.log(`Sleeping for ${sleepAmount}`)
            await sleep(sleepAmount)
        }
    }
    console.log(`Moved ${amount} blocks`)
}
