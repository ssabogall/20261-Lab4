import docClient from "../config/dynamo.js";
import { PutCommand, GetCommand, ScanCommand } from "@aws-sdk/lib-dynamodb";

const TABLE = "tb_books";

export const getBooksById = async (req, res) => {
  const command = new GetCommand({
    TableName: TABLE,
    Key: { 
      id: req.params.id, 
    }
  });
  const result = await docClient.send(command);
  console.log(result.Item);
  res.json(result.Item)  
  return res;
};

export const getBooks = async (req, res) => {
  const command = new ScanCommand({ TableName: TABLE });
  const result = await docClient.send(command);
  const books = result.Items || [];

  console.log("Books fetched:", books);
  res.status(200).json(books);
  return result.Items;
};

