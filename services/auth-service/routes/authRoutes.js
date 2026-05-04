import express from "express";
import { login, getProfile } from "../controllers/authController.js";

const router = express.Router();

router.post("/login", login);
router.get("/profile/:id", getProfile);

export default router;
