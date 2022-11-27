//const { moveBlocks } = require("../utils/move-blocks")
import { moveBlocks } from "../utils/move-blocks"

const BLOCKS = 2
const SLEEP_AMOUNT = 1000

async function mine(sleepAmount: number | undefined) {
    await moveBlocks(BLOCKS, (sleepAmount = SLEEP_AMOUNT))
}

mine(SLEEP_AMOUNT)
    .then(() => process.exit(0))
    .catch((error) => {
        console.log(error)
        process.exit(1)
    })
