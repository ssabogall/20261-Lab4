import React, { useState, useEffect } from 'react';
import { api } from '../lib/api';

import { Link, useParams } from 'react-router-dom';
import { Row, Col, Image, ListGroup, Badge, Spinner } from 'react-bootstrap';
import { Button } from 'react-bootstrap';


const BookScreen = () => {
    const [book, setBook] = useState({});
    const [review, setReview] = useState(null);
    const [reviewLoading, setReviewLoading] = useState(false);
    const { id } = useParams();

    useEffect(() => {
        const fetchBook = async () => {
            const { data } = await api.get(`/api/books/${id}`);
            setBook(data);

            // Fetch enriched data from reviews-service using the book title
            if (data.name) {
                setReviewLoading(true);
                try {
                    const { data: reviewData } = await api.get(
                        `/api/reviews/${encodeURIComponent(data.name)}`
                    );
                    setReview(reviewData);
                } catch (error) {
                    console.warn("No review data found:", error.message);
                } finally {
                    setReviewLoading(false);
                }
            }
        };
        fetchBook();
    }, [id]);


    return (
        <>
            <div className="mb-4">
                <Link to='/' style={{ textDecoration: 'none' }}>
                    <Button variant='light' aria-label="Regresar a la página principal">
                        ← Regresar al Catálogo
                    </Button>
                </Link>
            </div>

            <Row>
                <Col md={4}>
                    <Image src={book.image} alt={book.name} fluid />
                </Col>

                <Col md={4}>
                    <ListGroup variant='flush'>
                        <ListGroup.Item><h3>{book.name}</h3></ListGroup.Item>
                        <ListGroup.Item>Autor: {book.author}</ListGroup.Item>
                        <ListGroup.Item>Descripción: {book.description}</ListGroup.Item>
                    </ListGroup>
                </Col>

                <Col md={3}>
                    <ListGroup variant='flush'>
                        <ListGroup.Item>
                            Estado: {book.countInStock > 0 ? 'Disponible' : 'No Disponible'} ({book.countInStock}) uds
                        </ListGroup.Item>
                        <ListGroup.Item><strong>Precio:</strong> {book.price}</ListGroup.Item>
                    </ListGroup>
                </Col>
            </Row>

            {/* Enriched data from reviews-service */}
            <Row className="mt-5">
                <Col>
                    <h5 className="mb-3">Información adicional</h5>
                    {reviewLoading && <Spinner animation="border" size="sm" />}
                    {!reviewLoading && review && (
                        <ListGroup variant='flush'>
                            {review.firstPublishYear && (
                                <ListGroup.Item>
                                    <strong>Año de publicación:</strong> {review.firstPublishYear}
                                </ListGroup.Item>
                            )}
                            {review.pageCount && (
                                <ListGroup.Item>
                                    <strong>Número de páginas:</strong> {review.pageCount}
                                </ListGroup.Item>
                            )}
                            {review.ratingsAverage && (
                                <ListGroup.Item>
                                    <strong>Calificación:</strong> {review.ratingsAverage} / 5
                                    <span className="text-muted ms-2">({review.ratingsCount} votos)</span>
                                </ListGroup.Item>
                            )}
                            {review.subjects?.length > 0 && (
                                <ListGroup.Item>
                                    <strong>Temas:</strong>{" "}
                                    {review.subjects.map((s, i) => (
                                        <Badge bg="secondary" className="me-1" key={i}>{s}</Badge>
                                    ))}
                                </ListGroup.Item>
                            )}
                        </ListGroup>
                    )}
                    {!reviewLoading && !review && (
                        <p className="text-muted">No se encontró información adicional para este libro.</p>
                    )}
                </Col>
            </Row>
        </>
    );
};

export default BookScreen;
