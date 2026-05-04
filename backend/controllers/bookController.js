import Book from "../models/bookModel.js";

export const getBooks = async (req, res) => {
  try {
    const books = await Book.find({});
    console.log("Books fetched:", books.length);
    res.status(200).json(books);
  } catch (error) {
    console.error("Error fetching books:", error.message);
    res.status(500).json({ message: "Error fetching books" });
  }
};

export const getBooksById = async (req, res) => {
  try {
    const book = await Book.findById(req.params.id);
    if (!book) {
      return res.status(404).json({ message: "Book not found" });
    }
    console.log("Book fetched:", book.name);
    res.status(200).json(book);
  } catch (error) {
    console.error("Error fetching book:", error.message);
    res.status(500).json({ message: "Error fetching book" });
  }
};
