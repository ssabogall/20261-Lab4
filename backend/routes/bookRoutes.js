import express from 'express';
import { getBooks, getBooksById, updateStock } from '../controllers/bookController.js';

const router = express.Router();

router.get('/',          getBooks);
router.get('/:id',       getBooksById);
router.put('/:id/stock', updateStock);     // PUT /api/books/:id/stock

export default router;
