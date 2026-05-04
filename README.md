# MyBookStore — Arquitectura de Microservicios

Aplicación web de librería virtual migrada de arquitectura monolítica a microservicios, desplegada en AWS EKS con Kubernetes.

Permite visualizar un catálogo de libros, ver el detalle de cada uno con información enriquecida desde Open Library, e iniciar sesión con un perfil de usuario.

---

## Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                  Cluster (local / EKS)              │
│                                                     │
│  ┌──────────┐    ┌─────────────────────────────┐    │
│  │ frontend │───▶│  Nginx / Ingress Controller │    │
│  │  :80     │    └──────────────┬──────────────┘    │
│  └──────────┘                   │                   │
│                    ┌────────────┼────────────┐      │
│                    ▼            ▼            ▼      │
│             ┌────────────┐ ┌─────────┐ ┌─────────┐  │
│             │   books-   │ │  auth-  │ │reviews- │  │
│             │  service   │ │ service │ │ service │  │
│             │   :5001    │ │  :5002  │ │  :5003  │  │
│             └─────┬──────┘ └────┬────┘ └────┬────┘  │
│                   │             │            │      │
│                   ▼             ▼            ▼      │
│            ┌──────────┐  ┌──────────┐ ┌──────────┐  │
│            │ MongoDB  │  │dummyjson │ │  Open    │  │
│            │ :27017   │  │ .com     │ │ Library  │  │
│            └──────────┘  └──────────┘ └──────────┘  │
└─────────────────────────────────────────────────────┘
```

## Microservicios

| Servicio | Puerto | Responsabilidad | Depende de |
|---|---|---|---|
| `frontend` | 80 | UI React servida con Nginx | books-service, auth-service, reviews-service |
| `books-service` | 5001 | CRUD de libros | MongoDB |
| `auth-service` | 5002 | Login y perfil de usuario | dummyjson.com (API externa) |
| `reviews-service` | 5003 | Información enriquecida de libros | openlibrary.org (API externa) |
| `mongodb` | 27017 | Base de datos de libros | — |

---

## Estructura del proyecto

```
proyecto-microservicio/
├── backend/                    # books-service (Node.js + Mongoose)
│   ├── config/db.js            # Conexión a MongoDB
│   ├── controllers/            # Lógica de negocio
│   ├── models/bookModel.js     # Schema Mongoose
│   ├── routes/                 # Rutas Express
│   ├── seeder.js               # Script para poblar la BD
│   ├── Dockerfile
│   └── .env.example
├── services/
│   ├── auth-service/           # Node.js + Express → dummyjson.com
│   │   ├── controllers/
│   │   ├── routes/
│   │   ├── Dockerfile
│   │   └── .env.example
│   └── reviews-service/        # Node.js + Express → openlibrary.org
│       ├── controllers/
│       ├── routes/
│       ├── Dockerfile
│       └── .env.example
├── frontend/                   # React + Vite + Nginx
│   ├── src/
│   │   ├── screens/
│   │   ├── components/
│   │   ├── context/AuthContext.jsx
│   │   └── lib/api.js
│   ├── default.conf.template   # Configuración Nginx con proxy a servicios
│   └── Dockerfile
├── k8s/                        # Manifiestos de Kubernetes (siguiente etapa)
└── docker-compose.yml          # Orquestación local
```

---

## Ejecución en local

### Prerequisitos
- Docker Desktop corriendo
- Node.js 20+ (para generar `package-lock.json`)

### 1. Crear archivos de variables de entorno

```bash
cp backend/.env.example backend/.env
cp services/auth-service/.env.example services/auth-service/.env
cp services/reviews-service/.env.example services/reviews-service/.env
```

### 2. Generar package-lock.json en cada servicio

```bash
cd backend && npm install && cd ..
cd services/auth-service && npm install && cd ../..
cd services/reviews-service && npm install && cd ../..
```

### 3. Levantar todos los contenedores

```bash
docker-compose up --build
```

### 4. Poblar MongoDB con datos de prueba

```bash
docker exec mybookstore-books npm run seeder
```

### 5. Abrir la aplicación

```
http://localhost
```

### Verificar que cada servicio responde

```
http://localhost:5001  →  { status: "Ok", service: "books-service" }
http://localhost:5002  →  { status: "Ok", service: "auth-service" }
http://localhost:5003  →  { status: "Ok", service: "reviews-service" }
```

### Credenciales de prueba (dummyjson.com)

```
usuario: emilys
contraseña: emilyspass
```

---

## Variables de entorno

### backend/.env
```
PORT=5001
MONGO_URI=mongodb://mongodb:27017/mybookstore
NODE_ENV=development
```

### services/auth-service/.env
```
PORT=5002
NODE_ENV=development
```

### services/reviews-service/.env
```
PORT=5003
NODE_ENV=development
```

---

## Estado del proyecto

- [x] Migración de arquitectura monolítica a microservicios
- [x] books-service — CRUD de libros con MongoDB
- [x] auth-service — autenticación vía dummyjson.com
- [x] reviews-service — información enriquecida vía Open Library
- [x] frontend — React + Nginx con proxy a microservicios
- [x] docker-compose.yml — orquestación local validada
- [ ] Manifiestos Kubernetes (k8s/)
- [ ] Despliegue en AWS EKS

---

## Próximos pasos — Kubernetes en AWS EKS

1. Crear carpeta `k8s/` con manifiestos por servicio
2. Configurar Ingress NGINX Controller
3. Crear Secrets de Kubernetes para credenciales
4. Configurar StatefulSet para MongoDB con PersistentVolumeClaim
5. Subir imágenes a Amazon ECR
6. Desplegar en cluster EKS
