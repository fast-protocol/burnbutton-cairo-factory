use starknet::ContractAddress;

#[starknet::interface]
pub trait IArenaTemplate<TContractState> {
    fn press_button(ref self: TContractState);
    fn finalize_round(ref self: TContractState);
    fn claim_vault(ref self: TContractState);
    fn get_round_info(self: @TContractState) -> (u64, u64, ContractAddress, u256, bool);
    fn get_vault_balance(self: @TContractState, user: ContractAddress) -> u256;
}

#[starknet::contract]
mod ArenaTemplate {
    use super::IArenaTemplate;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, contract_address_const};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        token_address: ContractAddress,
        protocol_treasury: ContractAddress,
        burn_address: ContractAddress,
        action_cost: u256,
        timer_buffer: u64,
        max_clicks_per_wallet: u32,
        
        // Active Round State
        round_id: u64,
        deadline: u64,
        last_leader: ContractAddress,
        main_pool: u256,
        next_round_fund: u256,
        is_active: bool,

        // O(1) Gas-Optimized Mappings (No historical loops)
        wallet_clicks: Map<(u64, ContractAddress), u32>,
        vault_balances: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ButtonPressed: ButtonPressed,
        RoundFinalized: RoundFinalized,
        VaultClaimed: VaultClaimed,
    }

    #[derive(Drop, starknet::Event)]
    struct ButtonPressed {
        #[key]
        round_id: u64,
        #[key]
        player: ContractAddress,
        new_deadline: u64,
        burned_amount: u256,
        pool_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RoundFinalized {
        #[key]
        round_id: u64,
        #[key]
        winner: ContractAddress,
        reward_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct VaultClaimed {
        #[key]
        player: ContractAddress,
        amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        protocol_treasury: ContractAddress,
        action_cost: u256,
        timer_buffer: u64,
        max_clicks_per_wallet: u32
    ) {
        self.token_address.write(token_address);
        self.protocol_treasury.write(protocol_treasury);
        self.burn_address.write(contract_address_const::<0xdead>());
        self.action_cost.write(action_cost);
        self.timer_buffer.write(timer_buffer);
        self.max_clicks_per_wallet.write(max_clicks_per_wallet);
        self.round_id.write(1);
    }

    #[abi(embed_v0)]
    impl ArenaTemplateImpl of IArenaTemplate<ContractState> {
        fn press_button(ref self: ContractState) {
            let caller = get_caller_address();
            let now = get_block_timestamp();
            let mut current_round = self.round_id.read();

            // Auto-finalize previous round if deadline passed
            if self.is_active.read() && now >= self.deadline.read() {
                self._settle_round(current_round);
                current_round += 1;
                self.round_id.write(current_round);
            }

            // Anti-whale per-wallet limit check
            let clicks = self.wallet_clicks.read((current_round, caller));
            let limit = self.max_clicks_per_wallet.read();
            if limit > 0 {
                assert(clicks < limit, 'Max clicks per wallet reached');
            }
            self.wallet_clicks.write((current_round, caller), clicks + 1);

            // Tokenomics split: 45% Burn, 44% Active Pool, 10% Next Round, 1% Treasury
            let cost = self.action_cost.read();
            let burn_share = (cost * 45) / 100;
            let pool_share = (cost * 44) / 100;
            let next_share = (cost * 10) / 100;
            let _treasury_share = cost - burn_share - pool_share - next_share;

            // TODO: Integrate ERC20 IERC20Dispatcher transfer_from calls here

            self.main_pool.write(self.main_pool.read() + pool_share);
            self.next_round_fund.write(self.next_round_fund.read() + next_share);

            let new_deadline = now + self.timer_buffer.read();
            self.deadline.write(new_deadline);
            self.last_leader.write(caller);
            self.is_active.write(true);

            self.emit(ButtonPressed {
                round_id: current_round,
                player: caller,
                new_deadline,
                burned_amount: burn_share,
                pool_amount: self.main_pool.read(),
            });
        }

        fn finalize_round(ref self: ContractState) {
            let now = get_block_timestamp();
            assert(self.is_active.read(), 'Round not active');
            assert(now >= self.deadline.read(), 'Timer still running');

            let current_round = self.round_id.read();
            self._settle_round(current_round);
            self.round_id.write(current_round + 1);
        }

        // O(1) constant gas withdrawal regardless of total rounds played
        fn claim_vault(ref self: ContractState) {
            let caller = get_caller_address();
            let amount = self.vault_balances.read(caller);
            assert(amount > 0, 'No rewards available');

            self.vault_balances.write(caller, 0);
            // TODO: Execute ERC20 transfer to caller

            self.emit(VaultClaimed { player: caller, amount });
        }

        fn get_round_info(self: @ContractState) -> (u64, u64, ContractAddress, u256, bool) {
            (
                self.round_id.read(),
                self.deadline.read(),
                self.last_leader.read(),
                self.main_pool.read(),
                self.is_active.read()
            )
        }

        fn get_vault_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.vault_balances.read(user)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _settle_round(ref self: ContractState, round_id: u64) {
            let winner = self.last_leader.read();
            let reward = self.main_pool.read();

            // Credit winner's O(1) vault balance directly
            let current_vault = self.vault_balances.read(winner);
            self.vault_balances.write(winner, current_vault + reward);

            // Rollover next round seed
            self.main_pool.write(self.next_round_fund.read());
            self.next_round_fund.write(0);
            self.is_active.write(false);

            self.emit(RoundFinalized { round_id, winner, reward_amount: reward });
        }
    }
}
