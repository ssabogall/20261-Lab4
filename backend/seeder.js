import mongoose from "mongoose";
import dotenv from "dotenv";
import Book from "./models/bookModel.js";

dotenv.config();

const books = [
  {
    name: "Cien años de soledad",
    author: "Gabriel García Márquez",
    description:
      "La historia de la familia Buendía a lo largo de siete generaciones en el pueblo ficticio de Macondo.",
    image: "https://covers.openlibrary.org/b/isbn/9780060883287-L.jpg",
    price: "$25.000",
    countInStock: 10,
  },
  {
    name: "El amor en los tiempos del cólera",
    author: "Gabriel García Márquez",
    description:
      "Una historia de amor que se desarrolla a lo largo de más de cincuenta años en una ciudad caribeña.",
    image: "https://covers.openlibrary.org/b/isbn/9780307389732-L.jpg",
    price: "$22.000",
    countInStock: 8,
  },
  {
    name: "1984",
    author: "George Orwell",
    description:
      "Una novela distópica que retrata una sociedad totalitaria bajo la vigilancia constante del Gran Hermano.",
    image: "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg",
    price: "$18.000",
    countInStock: 15,
  },
  {
    name: "El principito",
    author: "Antoine de Saint-Exupéry",
    description:
      "Un clásico de la literatura universal que narra el viaje de un pequeño príncipe por el universo.",
    image: "https://covers.openlibrary.org/b/isbn/9780156012195-L.jpg",
    price: "$15.000",
    countInStock: 20,
  },
  {
    name: "Don Quijote de la Mancha",
    author: "Miguel de Cervantes",
    description:
      "Las aventuras del ingenioso hidalgo Don Quijote y su fiel escudero Sancho Panza.",
    image: "https://covers.openlibrary.org/b/isbn/9788420412146-L.jpg",
    price: "$30.000",
    countInStock: 5,
  },
  {
    name: "La sombra del viento",
    author: "Carlos Ruiz Zafón",
    description:
      "Un misterio literario ambientado en la Barcelona de posguerra que gira en torno a un libro olvidado.",
    image: "https://covers.openlibrary.org/b/isbn/9788408163435-L.jpg",
    price: "$28.000",
    countInStock: 7,
  },
];

const seedDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("MongoDB connected for seeding...");

    await Book.deleteMany({});
    console.log("Existing books cleared");

    await Book.insertMany(books);
    console.log(`${books.length} books inserted successfully`);

    process.exit(0);
  } catch (error) {
    console.error("Seeder error:", error.message);
    process.exit(1);
  }
};

seedDB();
