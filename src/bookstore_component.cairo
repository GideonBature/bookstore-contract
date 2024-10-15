#[derive(Copy, Drop, Serde, starknet::Store, Hash)]
pub struct Book {
    name: felt252,
    genre: felt252,
    author: felt252,
}

#[starknet::interface]
pub trait IBookStore<TContractState> {
    fn add_book(ref self: TContractState, id: felt252, new_book: Book);
    fn get_books(self: @TContractState) -> Array<(felt252, Book)>;
    fn get_book(self: @TContractState, id: felt252) -> Book;
    fn update_book(ref self: TContractState, id: felt252, updated_book: Book);
    // https://book.cairo-lang.org/ch14-03-contract-events.html
    fn delete_book(ref self: TContractState, id: felt252);
    fn increase_book_count(ref self: TContractState);
}

#[starknet::component]
pub mod BookStoreComponent {
    use starknet::event::EventEmitter;
    use super::Book;

    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
        StorageMapReadAccess, StorageMapWriteAccess
    };

    use core::starknet::{ContractAddress, get_caller_address};

    #[storage]
    pub struct Storage {
        pub books: Map<felt252, Book>, // map book_id => book Struct
        pub librarian: ContractAddress,
        pub books_stored: Vec<(felt252, Book)>,
        pub count: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BookAdded: BookAdded,
        BookUpdated: BookUpdated,
        BookDeleted: BookDeleted,
        LibrarianSet: LibrarianSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BookAdded {
        id: felt252,
        book: Book,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BookUpdated {
        id: felt252,
        book: Book,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BookDeleted {
        id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LibrarianSet {
        new_librarian: ContractAddress,
    }

    // #[constructor]
    // fn constructor(ref self: ContractState, librarian: ContractAddress) {
    //     self.librarian.write(librarian);
    // }

    mod Errors {
        pub const NOT_LIBRARIAN: felt252 = 'Caller is not the librarian';
        pub const ZERO_ADDRESS_LIBRARIAN: felt252 = 'Librarian is the zero address';
    }

    #[embeddable_as(BookStore)]
    impl BookStoreImpl<TContractState, +HasComponent<TContractState>> of super::IBookStore<ComponentState<ContractState>> {

        fn add_book(ref self: ComponentState<TContractState>, id: felt252, new_book: Book) {
            
            self.assert_only_librarian();

            let book = Book { ..new_book };
            self.books.write(id, book);

            self.books_stored.append().write((id, book));

            self.emit(BookAdded { id, book });
        }

        fn get_books(self: @ComponentState<TContractState>) -> Array<(felt252, Book)> {
            let mut books: Array<(felt252, Book)> = array![];
            let length: u64 = self.books_stored.len();
            let mut i: u64 = 0;

            while i != length {
                let (id, book) = self.books_stored.at(i).read();
                books.append((id, book));
                i = i + 1;
            };

            books
        }

        fn get_book(self: @ComponentState<TContractState>, id: felt252) -> Book {
            self.books.read(id)
        }

        fn update_book(ref self: ComponentState<TContractState>, id: felt252, updated_book: Book) {
            
            self.assert_only_librarian();

            self.books.write(id, updated_book);

            let mut index = 0;
            let length = self.books_stored.len();
            while index != length {
                let (book_id, _book) = self.books_stored.at(index).read();
                if book_id == id {
                    self.books_stored.at(index).write((id, updated_book));
                    break;
                }
                index = index + 1;
            };

            self.emit(BookUpdated { id, book: updated_book });
        }

        fn delete_book(ref self: ComponentState<TContractState>, id: felt252) {
            
            self.assert_only_librarian();

            let book = Book {
                name: '',
                genre: '',
                author: '',
            };

            self.books.write(id, book);

            let mut index = 0;
            let length = self.books_stored.len();
            while index != length {
                let (book_id, _book) = self.books_stored.at(index).read();
                if book_id == id {
                    self.books_stored.at(index).write((id, book));
                    break;
                }
                index = index + 1;
            };

            self.emit(BookDeleted { id });
        }

        fn increase_book_count(ref self: ComponentState<TContractState>) {
            self.count.write(self.count.read() + 1);
        }
    }

    #[generate_trait]
    impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, librarian: ContractAddress) {
            self._set_librarian(librarian);
        }

        fn assert_only_librarian(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            let librarian = self.librarian.read();

            assert(!librarian.is_zero(), Errors::ZERO_ADDRESS_LIBRARIAN);
            assert(caller == librarian, Errors::NOT_LIBRARIAN);
        }

        fn _set_librarian(ref self: ComponentState<TContractState>, librarian: ContractAddress) {
            self.librarian.write(librarian);

            self.emit(
                LibrarianSet {
                    new_librarian: librarian
                }
            );
        }
    }
}
