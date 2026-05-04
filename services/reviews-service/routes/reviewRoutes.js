import express from "express";
import { getReviewsByTitle } from "../controllers/reviewController.js";

const router = express.Router();

router.get("/:title", getReviewsByTitle);

export default router;
