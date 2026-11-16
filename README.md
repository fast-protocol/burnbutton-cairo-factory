# 🔴 BurnButton Factory (Starknet / Cairo)

**BurnButton Factory** is a permissionless, non-custodial **Burn-as-a-Service (BaaS)** and skill-based on-chain countdown protocol designed for the Starknet ecosystem. 

Inspired by the legendary Reddit social psychology experiment (*The Button*), BurnButton transforms token deflation into a viral, high-retention multiplayer coordination game.

## 🎮 Core Mechanics (Skill & Game Theory)
* **Deterministic Last-Click Rules:** No RNG, no luck, no gambling. Every participant acts as a strategist in an open-information coordination game.
* **The Countdown Loop:** Users pay a micro-fee in a partner project's ERC-20 token to press the button and reset a global countdown timer (e.g., 60 seconds).
* **The Endgame:** When the timer reaches zero, the absolute last strategist to press the button claims the accumulated **Arena Prize Pool**.
* **Anti-Whale Fairness:** Configurable per-wallet action limits prevent single large holders from monopolizing rounds, ensuring fair competition and viral community FOMO.

## 🔥 Tokenomics & Automated Deflation
Every button press executes 3 atomic on-chain transfers:
* **45% Permanently Burned:** Sent to a dead address, permanently reducing circulating supply.
* **44% Active Arena Pool:** Rewards the final winner of the round.
* **10% Next-Round Seed:** Automatically bootstraps the subsequent match so the arena never starts at zero.
* **1% Protocol Treasury:** Sustains infrastructure and indexing nodes.

## 🏗 Architecture (Starknet Migration v3.0)
* **`ArenaFactory.cairo`:** Uses `deploy_syscall` to allow any Starknet project or community to launch a branded burn arena in one click.
* **`ArenaTemplate.cairo`:** Features **O(1) gas-optimized vault withdrawals** (eliminating historical loop bottlenecks) and dynamic round parameters.
* **Async Indexer:** High-speed Python indexer (`starknet.py`) with sub-second WebSocket state synchronization.

## 🌐 Live EVM Proof-of-Work
Battle-tested v2.0 mainnet deployment: [burnbutton.xyz](https://burnbutton.xyz)
# burnbutton-cairo-factory
Permissionless "Burn-as-a-Service" &amp; Skill-Based On-Chain Countdown Protocol built in Cairo for Starknet.
