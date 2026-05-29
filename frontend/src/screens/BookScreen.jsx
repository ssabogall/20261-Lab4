import React, { useState, useEffect } from 'react';
import { api } from '../lib/api';
import { Link, useParams } from 'react-router-dom';
import { Row, Col, Image, ListGroup, Badge, Spinner, Alert, Button } from 'react-bootstrap';

/* ─── Panel de edición de stock ─────────────────────────────────── */
const StockEditor = ({ bookId, currentStock, outOfStock, onUpdated }) => {
    const [stock,   setStock]   = useState(currentStock);
    const [saving,  setSaving]  = useState(false);
    const [success, setSuccess] = useState(false);
    const [error,   setError]   = useState(null);

    useEffect(() => { setStock(currentStock); }, [currentStock]);

    const handleChange = (delta) => {
        setStock(prev => Math.max(0, prev + delta));
        setSuccess(false);
        setError(null);
    };

    const handleSave = async () => {
        setSaving(true);
        setSuccess(false);
        setError(null);
        try {
            const { data } = await api.put(`/api/books/${bookId}/stock`, {
                countInStock: stock,
            });
            setSuccess(true);
            onUpdated(data);
            setTimeout(() => setSuccess(false), 3000);
        } catch (err) {
            setError("No se pudo actualizar el stock.");
        } finally {
            setSaving(false);
        }
    };

    const dirty = stock !== currentStock;

    return (
        <div
            className="p-3 rounded"
            style={{ background: '#f8f9fa', border: '1px solid #dee2e6' }}
        >
            <p className="mb-2 fw-semibold" style={{ fontSize: '0.9rem' }}>
                Actualizar stock
            </p>

            {/* Controles +/- */}
            <div className="d-flex align-items-center gap-2 mb-3">
                <Button
                    variant="outline-secondary"
                    size="sm"
                    onClick={() => handleChange(-1)}
                    disabled={stock <= 0 || saving}
                    style={{ width: '36px', fontWeight: 'bold' }}
                >
                    −
                </Button>
                <span
                    className="fw-bold text-center"
                    style={{
                        minWidth: '40px',
                        fontSize: '1.2rem',
                        color: stock === 0 ? '#6c757d' : stock == 0 ? '#dc3545' : '#212529',
                    }}
                >
                    {stock}
                </span>
                <Button
                    variant="outline-secondary"
                    size="sm"
                    onClick={() => handleChange(+1)}
                    disabled={saving}
                    style={{ width: '36px', fontWeight: 'bold' }}
                >
                    +
                </Button>
            </div>

            {/* Botón guardar */}
            <Button
                variant={dirty ? (outOfStock && stock > 0 ? "success" : "primary") : "secondary"}
                size="sm"
                className="w-100"
                onClick={handleSave}
                disabled={!dirty || saving}
            >
                {saving
                    ? <><Spinner animation="border" size="sm" className="me-1" /> Guardando…</>
                    : outOfStock && stock > 0
                        ? "✅ Reabastecer libro"
                        : "Guardar cambios"
                }
            </Button>

            {/* Feedback */}
            {success && (
                <p className="text-success mt-2 mb-0" style={{ fontSize: '0.82rem' }}>
                    ✅ Stock actualizado correctamente
                </p>
            )}
            {error && (
                <p className="text-danger mt-2 mb-0" style={{ fontSize: '0.82rem' }}>
                    ❌ {error}
                </p>
            )}
        </div>
    );
};

/* ─── Pantalla de detalle del libro ─────────────────────────────── */
const BookScreen = () => {
    const [book,          setBook]          = useState({});
    const [review,        setReview]        = useState(null);
    const [reviewLoading, setReviewLoading] = useState(false);
    const { id } = useParams();

    useEffect(() => {
        const fetchBook = async () => {
            const { data } = await api.get(`/api/books/${id}`);
            setBook(data);
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

    const handleStockUpdated = (updatedBook) => {
        setBook(updatedBook);
    };

    return (
        <>
            <div className="mb-4">
                <Link to='/' style={{ textDecoration: 'none' }}>
                    <Button variant='light' aria-label="Regresar a la página principal">
                        ← Regresar al Catálogo
                    </Button>
                </Link>
            </div>

            {/* ── Alerta Agotado — prioridad máxima ────────────── */}
            {book.outOfStock && (
                <Alert
                    variant="danger"
                    className="d-flex align-items-center gap-2 mb-4"
                    style={{ borderLeft: '4px solid #dc3545' }}
                >
                    <span style={{ fontSize: '1.2rem' }}>🚫</span>
                    <div>
                        <strong>Libro agotado</strong>
                        {book.outOfStockSince && (
                            <span className="text-muted ms-2" style={{ fontSize: '0.85rem' }}>
                                — Sin stock desde{' '}
                                {new Date(book.outOfStockSince).toLocaleDateString('es-CO', {
                                    year: 'numeric',
                                    month: 'long',
                                    day: 'numeric',
                                    hour: '2-digit',
                                    minute: '2-digit',
                                })}
                            </span>
                        )}
                    </div>
                </Alert>
            )}

            {/* ── Alerta Poco Stock — solo si no está agotado ──── */}
            {book.lowStock && !book.outOfStock && (
                <Alert
                    variant="warning"
                    className="d-flex align-items-center gap-2 mb-4"
                    style={{ borderLeft: '4px solid #fd7e14' }}
                >
                    <span style={{ fontSize: '1.2rem' }}>⚠️</span>
                    <div>
                        <strong>¡Pocas unidades disponibles!</strong>
                        <span className="text-muted ms-2">
                            Solo quedan <strong>{book.countInStock}</strong> unidad{book.countInStock !== 1 ? 'es' : ''}.
                        </span>
                    </div>
                </Alert>
            )}

            <Row>
                {/* Portada */}
                <Col md={4}>
                    <Image
                        src={book.image}
                        alt={book.name}
                        fluid
                        style={{
                            filter: book.outOfStock ? 'grayscale(50%)' : 'none',
                            opacity: book.outOfStock ? 0.75 : 1,
                            transition: 'filter 0.3s, opacity 0.3s',
                        }}
                    />
                </Col>

                {/* Info del libro */}
                <Col md={4}>
                    <ListGroup variant='flush'>
                        <ListGroup.Item><h3>{book.name}</h3></ListGroup.Item>
                        <ListGroup.Item>Autor: {book.author}</ListGroup.Item>
                        <ListGroup.Item>Descripción: {book.description}</ListGroup.Item>
                    </ListGroup>
                </Col>

                {/* Panel de stock + precio + editor */}
                <Col md={3}>
                    <ListGroup variant='flush'>
                        <ListGroup.Item>
                            <div className="d-flex align-items-center gap-2 flex-wrap">
                                <span>
                                    Estado:{' '}
                                    {book.outOfStock
                                        ? <span className="text-muted">Agotado</span>
                                        : book.countInStock > 0
                                            ? 'Disponible'
                                            : 'No Disponible'
                                    }{' '}
                                    ({book.countInStock}) uds
                                </span>
                                {book.outOfStock && (
                                    <Badge bg="dark" style={{ fontSize: '0.7rem' }}>
                                        🚫 Agotado
                                    </Badge>
                                )}
                                {book.lowStock && !book.outOfStock && (
                                    <Badge bg="danger" style={{ fontSize: '0.7rem' }}>
                                        ⚠ Poco stock
                                    </Badge>
                                )}
                            </div>
                        </ListGroup.Item>
                        <ListGroup.Item>
                            <strong>Precio:</strong> {book.price}
                        </ListGroup.Item>

                        {/* Editor de stock */}
                        {book.id && (
                            <ListGroup.Item className="px-0 pt-3">
                                <StockEditor
                                    bookId={book.id}
                                    currentStock={book.countInStock ?? 0}
                                    outOfStock={book.outOfStock ?? false}
                                    onUpdated={handleStockUpdated}
                                />
                            </ListGroup.Item>
                        )}
                    </ListGroup>
                </Col>
            </Row>

            {/* Información adicional desde reviews-service */}
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
                                    <strong>Temas:</strong>{' '}
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
