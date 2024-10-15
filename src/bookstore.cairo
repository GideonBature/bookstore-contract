#[starknet::contract]
mod BookCounter {
    use BookStoreComponent::InternalTrait;
    use book_contract::bookstore_component::BookStoreComponent;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: BookStoreComponent, storage: bookstore, event: BookStoreEvent);

    #[abi(embed_v0)]
    impl BookStoreImpl = BookStoreComponent::BookStore<ContractState>;
    impl BookStoreInternalImpl = BookStoreComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u128,
        #[substorage(v0)]
        bookstore: BookStoreComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BookStoreEvent: BookStoreComponent::Event,
    }

    #[constructor]
    fn constructor(ref mut self: ContractState, librarian: ContractAddress) {
        self.bookstore.initializer(librarian);
    }

    #[abi(embed_v0)]
    fn count(ref self: ContractState) {
        self.bookstore.assert_only_librarian();
        self.counter.write(self.counter.read() + 1);

        self.bookstore.increase_book_count();
    }
}