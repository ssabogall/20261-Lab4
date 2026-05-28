import docClient from "../config/dynamo.js";
import { ScanCommand, GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const TABLE_NAME  = process.env.DYNAMO_TABLE  || "bookstore-books";
const THRESHOLD   = parseInt(process.env.STOCK_THRESHOLD || "3");

/**
 * Retorna todos los libros de la tabla DynamoDB.
 */
export const getAllBooks = async () => {
  const result = await docClient.send(new ScanCommand({ TableName: TABLE_NAME }));
  return result.Items || [];
};

/**
 * Retorna un libro por su `id`.
 */
export const getBookById = async (id) => {
  const result = await docClient.send(
    new GetCommand({ TableName: TABLE_NAME, Key: { id } })
  );
  return result.Item || null;
};

/**
 * Actualiza el stock de un libro y recalcula lowStock (threshold <= 3).
 * En producción lowStock lo gestiona la Lambda; aquí lo calculamos
 * directamente para que funcione también en local sin Lambda.
 */
export const updateBookStock = async (id, newStock) => {
  const stock    = Math.max(0, parseInt(newStock));   // nunca negativo
  const lowStock = stock <= THRESHOLD;

  const result = await docClient.send(
    new UpdateCommand({
      TableName: TABLE_NAME,
      Key: { id },
      UpdateExpression:
        "SET countInStock = :stock, lowStock = :lowStock",
      ExpressionAttributeValues: {
        ":stock":    stock,
        ":lowStock": lowStock,
      },
      ConditionExpression: "attribute_exists(id)",    // evita crear items fantasma
      ReturnValues: "ALL_NEW",
    })
  );

  return result.Attributes;
};
