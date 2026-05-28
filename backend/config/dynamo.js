import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";
import { fromEnv } from "@aws-sdk/credential-providers";

const region      = process.env.AWS_REGION  || "us-east-1";
const environment = process.env.NODE_ENV    || "development";

let clientConfig = { region };

if (environment === "production") {
  // En EKS usa el IAM Role del pod — no necesita credenciales explícitas
  console.log("DynamoDB: modo production (IAM Role)");

} else {
  // Dev local: apunta a DynamoDB Local en localhost:8000
  console.log("DynamoDB: modo development → http://localhost:8000");
  clientConfig.endpoint    = "http://localhost:8000";
  clientConfig.credentials = fromEnv();
}

const client    = new DynamoDBClient(clientConfig);
const docClient = DynamoDBDocumentClient.from(client);

export default docClient;
