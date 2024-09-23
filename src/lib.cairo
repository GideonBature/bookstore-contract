#[derive(Copy, Drop, Serde, starknet::Store, Hash)]
pub struct Book {
    name: felt252,
    genre: felt252,
    author: felt252,
}

#[starknet::interface]
pub trait IBookStore<TBookStore> {
    fn add_book(ref self: TBookStore, id: felt252, new_book: Book);
    fn get_books(self: @TBookStore) -> Array<(felt252, Book)>;
    fn get_book(self: @TBookStore, id: felt252) -> Book;
    fn update_book(ref self: TBookStore, id: felt252, updated_book: Book);
    // https://book.cairo-lang.org/ch14-03-contract-events.html
    fn delete_book(ref self: TBookStore, id: felt252);
}

#[starknet::contract]
pub mod BookStore {
    use starknet::event::EventEmitter;
    use super::Book;

    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait, Map,
        StorageMapReadAccess, StorageMapWriteAccess
    };

    use core::starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        books: Map<felt252, Book>, // map book_id => book Struct
        librarian: ContractAddress,
        books_stored: Vec<(felt252, Book)>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookAdded: BookAdded,
        BookUpdated: BookUpdated,
        BookDeleted: BookDeleted,
    }

    #[derive(Drop, starknet::Event)]
    struct BookAdded {
        id: felt252,
        book: Book,
    }

    #[derive(Drop, starknet::Event)]
    struct BookUpdated {
        id: felt252,
        book: Book,
    }

    #[derive(Drop, starknet::Event)]
    struct BookDeleted {
        id: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, librarian: ContractAddress) {
        self.librarian.write(librarian);
    }

    #[abi(embed_v0)]
    impl BookStoreImpl of super::IBookStore<ContractState> {
        fn add_book(ref self: ContractState, id: felt252, new_book: Book) {
            let caller = get_caller_address();
            let librarian = self.librarian.read();

            assert(caller == librarian, 'Only Librarian can add books');

            let book = Book { ..new_book };
            self.books.write(id, book);

            self.books_stored.append().write((id, book));

            self.emit(BookAdded { id, book });
        }

        fn get_books(self: @ContractState) -> Array<(felt252, Book)> {
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

        fn get_book(self: @ContractState, id: felt252) -> Book {
            self.books.read(id)
        }

        fn update_book(ref self: ContractState, id: felt252, updated_book: Book) {
            let caller = get_caller_address();
            let librarian = self.librarian.read();
            assert(caller == librarian, 'Only Librarian can update books');
            self.books.write(id, updated_book);

            let mut index = 0;
            let length = self.books_stored.len();
            while index != length {
                let (book_id, _book) = self.books_stored.at(index).read();
                if book_id == id {
                    self.books_stored.at(index).write((id, updated_book));
                }
                index = index + 1;
            };

            self.emit(BookUpdated { id, book: updated_book });
        }

        fn delete_book(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let librarian = self.librarian.read();
            assert(caller == librarian, 'Only Librarian can delete books');

            self.emit(BookDeleted { id });
        }
    }
}
