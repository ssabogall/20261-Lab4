/**
 * seeder.js — Puebla la tabla DynamoDB con libros de ejemplo.
 * Uso: npm run seeder
 */

import dotenv from "dotenv";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, ScanCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { v4 as uuidv4 } from "uuid";

dotenv.config();

const TABLE_NAME   = process.env.DYNAMO_TABLE || "bookstore-books";
const region       = process.env.AWS_REGION   || "us-east-1";
const environment  = process.env.NODE_ENV     || "development";

// En dev apunta a DynamoDB Local, igual que dynamo.js
const clientConfig = {
  region,
  credentials: {
    accessKeyId:     "local",
    secretAccessKey: "local",
  },
  ...(environment !== "production" && {
    endpoint: "http://localhost:8000",
  }),
};

const client    = new DynamoDBClient(clientConfig);
const docClient = DynamoDBDocumentClient.from(client);

const books = [
  {
    name: "Cien años de soledad",
    author: "Gabriel García Márquez",
    description: "La historia de la familia Buendía a lo largo de siete generaciones en Macondo.",
    image: "https://covers.openlibrary.org/b/isbn/9780060883287-L.jpg",
    price: "$25.000",
    countInStock: 10,
    lowStock: false,
  },
  {
    name: "El amor en los tiempos del cólera",
    author: "Gabriel García Márquez",
    description: "Una historia de amor que se desarrolla a lo largo de más de cincuenta años.",
    image: "https://covers.openlibrary.org/b/isbn/9780307389732-L.jpg",
    price: "$22.000",
    countInStock: 8,
    lowStock: false,
  },
  {
    name: "1984",
    author: "George Orwell",
    description: "Una novela distópica bajo la vigilancia constante del Gran Hermano.",
    image: "https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg",
    price: "$18.000",
    countInStock: 15,
    lowStock: false,
  },
  {
    name: "El principito",
    author: "Antoine de Saint-Exupéry",
    description: "El viaje de un pequeño príncipe por el universo.",
    image: "https://covers.openlibrary.org/b/isbn/9780156012195-L.jpg",
    price: "$15.000",
    countInStock: 20,
    lowStock: false,
  },
  {
    name: "Don Quijote de la Mancha",
    author: "Miguel de Cervantes",
    description: "Las aventuras del ingenioso hidalgo Don Quijote y Sancho Panza.",
    image: "https://covers.openlibrary.org/b/isbn/9788420412146-L.jpg",
    price: "$30.000",
    countInStock: 2,
    lowStock: true,
  },
  {
    name: "La sombra del viento",
    author: "Carlos Ruiz Zafón",
    description: "Un misterio literario en la Barcelona de posguerra.",
    image: "https://covers.openlibrary.org/b/isbn/9788408163435-L.jpg",
    price: "$28.000",
    countInStock: 3,
    lowStock: true,
  },
];

const seedDB = async () => {
  try {
    console.log(`Conectando a DynamoDB — tabla: ${TABLE_NAME}`);

    // Limpiar registros existentes
    const existing = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
    for (const item of existing.Items || []) {
      await docClient.send(new DeleteCommand({ TableName: TABLE_NAME, Key: { id: item.id } }));
    }
    console.log(`${existing.Items?.length || 0} libros eliminados`);

    // Insertar nuevos
    for (const book of books) {
      await docClient.send(
        new PutCommand({
          TableName: TABLE_NAME,
          Item: { id: uuidv4(), ...book },
        })
      );
    }
    console.log(`✅ ${books.length} libros insertados correctamente en DynamoDB`);
    process.exit(0);
  } catch (error) {
    console.error("❌ Seeder error:", error.message);
    process.exit(1);
  }
};

seedDB();
