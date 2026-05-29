import React from 'react';
import { Card, Badge } from 'react-bootstrap';
import { Link } from 'react-router-dom';

const Book = ({ book }) => {
    return (
        <Card
            className="my-3 p-3 rounded shadow-sm h-100 book-card"
            style={{
                transition: 'transform 0.2s',
                position: 'relative',
                opacity: book.outOfStock ? 0.6 : 1,
            }}
        >
            {/* Badge Agotado tiene prioridad sobre Poco stock */}
            {book.outOfStock ? (
                <Badge
                    bg="dark"
                    style={{
                        position: 'absolute',
                        top: '12px',
                        left: '12px',
                        zIndex: 10,
                        fontSize: '0.7rem',
                        letterSpacing: '0.03em',
                        padding: '5px 8px',
                        borderRadius: '6px',
                    }}
                >
                    🚫 Agotado
                </Badge>
            ) : book.lowStock && (
                <Badge
                    bg="danger"
                    style={{
                        position: 'absolute',
                        top: '12px',
                        left: '12px',
                        zIndex: 10,
                        fontSize: '0.7rem',
                        letterSpacing: '0.03em',
                        padding: '5px 8px',
                        borderRadius: '6px',
                    }}
                >
                    ⚠ Poco stock
                </Badge>
            )}

            <Link to={`/book/${book.id}`}>
                <Card.Img
                    src={book.image || '/placeholder.png'}
                    variant="top"
                    style={{
                        height: '250px',
                        objectFit: 'cover',
                        filter: book.outOfStock ? 'grayscale(60%)' : 'none',
                    }}
                />
            </Link>
            <Card.Body className="d-flex flex-column">
                <Link to={`/book/${book.id}`} className="text-decoration-none">
                    <Card.Title as="div">
                        <strong>{book.name}</strong>
                    </Card.Title>
                </Link>
                <Card.Text as="h5" className="mt-auto fw-bold">{book.price}</Card.Text>
            </Card.Body>
        </Card>
    );
};

export default Book;
