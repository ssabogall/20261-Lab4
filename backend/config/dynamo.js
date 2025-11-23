import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { fromIni } from "@aws-sdk/credential-providers";
import { fromEnv } from "@aws-sdk/credential-providers";


const region = process.env.AWS_REGION || "us-east-1";
const profile = process.env.AWS_PROFILE || "default";
const environment = process.env.NODE_ENV || "dev";

let clientConfig = { region };

if (environment === "prod") {
  console.log("Running application in production mode...");
} else {
  //clientConfig.credentials = fromIni({ profile });
  console.log(`Running application in dev mode: ${profile}`);
}

const client = new DynamoDBClient({
  region: process.env.AWS_REGION,
  credentials: fromEnv()
});
const docClient = DynamoDBDocumentClient.from(client);

export default docClient;