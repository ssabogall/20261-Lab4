import { getAllBooks, getBookById, updateBookStock } from "../models/bookModel.js";

export const getBooks = async (req, res) => {
  try {
    const books = await getAllBooks();
    console.log("Books fetched from DynamoDB:", books.length);
    res.status(200).json(books);
  } catch (error) {
    console.error("Error fetching books:", error.message);
    res.status(500).json({ message: "Error fetching books" });
  }
};

export const getBooksById = async (req, res) => {
  try {
    const book = await getBookById(req.params.id);
    if (!book) {
      return res.status(404).json({ message: "Book not found" });
    }
    console.log("Book fetched:", book.name, "| lowStock:", book.lowStock ?? false);
    res.status(200).json(book);
  } catch (error) {
    console.error("Error fetching book:", error.message);
    res.status(500).json({ message: "Error fetching book" });
  }
};

export const updateStock = async (req, res) => {
  try {
    const { id }          = req.params;
    const { countInStock } = req.body;

    if (countInStock === undefined || countInStock === null) {
      return res.status(400).json({ message: "countInStock es requerido" });
    }

    const updated = await updateBookStock(id, countInStock);
    console.log(
      `Stock actualizado — libro: ${id} | stock: ${updated.countInStock} | lowStock: ${updated.lowStock}`
    );
    res.status(200).json(updated);
  } catch (error) {
    if (error.name === "ConditionalCheckFailedException") {
      return res.status(404).json({ message: "Book not found" });
    }
    console.error("Error updating stock:", error.message);
    res.status(500).json({ message: "Error updating stock" });
  }
};
