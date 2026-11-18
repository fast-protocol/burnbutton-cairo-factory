use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IArenaFactory<TContractState> {
    fn create_arena(
        ref self: TContractState,
        token_address: ContractAddress,
        action_cost: u256,
        timer_buffer: u64,
        max_clicks_per_wallet: u32
    ) -> ContractAddress;
    fn get_arenas_count(self: @TContractState) -> u64;
    fn get_arena_by_id(self: @TContractState, arena_id: u64) -> ContractAddress;
}

#[starknet::contract]
mod ArenaFactory {
    use super::IArenaFactory;
    use starknet::{ContractAddress, ClassHash, get_caller_address};
    use starknet::syscalls::deploy_syscall;
    use starknet::SyscallResultTrait;
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapReadAccess, StorageMapWriteAccess
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        protocol_treasury: ContractAddress,
        arena_class_hash: ClassHash,
        arenas_count: u64,
        arenas: Map<u64, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ArenaCreated: ArenaCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct ArenaCreated {
        #[key]
        arena_id: u64,
        #[key]
        token_address: ContractAddress,
        arena_address: ContractAddress,
        creator: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        protocol_treasury: ContractAddress,
        arena_class_hash: ClassHash
    ) {
        self.owner.write(owner);
        self.protocol_treasury.write(protocol_treasury);
        self.arena_class_hash.write(arena_class_hash);
        self.arenas_count.write(0);
    }

    #[abi(embed_v0)]
    impl ArenaFactoryImpl of IArenaFactory<ContractState> {
        fn create_arena(
            ref self: ContractState,
            token_address: ContractAddress,
            action_cost: u256,
            timer_buffer: u64,
            max_clicks_per_wallet: u32
        ) -> ContractAddress {
            let creator = get_caller_address();
            let new_id = self.arenas_count.read() + 1;

            // Prepare constructor calldata for ArenaTemplate
            let mut calldata: Array<felt252> = array![];
            token_address.serialize(ref calldata);
            self.protocol_treasury.read().serialize(ref calldata);
            action_cost.serialize(ref calldata);
            timer_buffer.serialize(ref calldata);
            max_clicks_per_wallet.serialize(ref calldata);

            // Deploy new isolated Arena instance via Starknet syscall
            let (arena_address, _) = deploy_syscall(
                self.arena_class_hash.read(),
                new_id.into(),
                calldata.span(),
                false
            ).unwrap_syscall();

            self.arenas.write(new_id, arena_address);
            self.arenas_count.write(new_id);

            self.emit(ArenaCreated {
                arena_id: new_id,
                token_address,
                arena_address,
                creator,
            });

            arena_address
        }

        fn get_arenas_count(self: @ContractState) -> u64 {
            self.arenas_count.read()
        }

        fn get_arena_by_id(self: @ContractState, arena_id: u64) -> ContractAddress {
            self.arenas.read(arena_id)
        }
    }
}
