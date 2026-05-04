import mongoose from "mongoose";

const bookSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    author: { type: String, required: true },
    description: { type: String, default: "" },
    image: { type: String, default: "" },
    price: { type: String, required: true },
    countInStock: { type: Number, default: 0 },
  },
  { timestamps: true }
);

const Book = mongoose.model("Book", bookSchema);

export default Book;
