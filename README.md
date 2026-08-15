# OZIRAF Backend

Backend API for OZIRAF built with NestJS, Prisma and PostgreSQL.

## Requirements

- Node.js
- npm
- PostgreSQL database

## Environment

Create a `.env` file with:

```env
DATABASE_URL="postgresql://USER:PASSWORD@HOST:PORT/DATABASE"
JWT_SECRET="your-secret"
PORT=3000
```

## Setup

```bash
npm install
npx prisma migrate dev
npm run start:dev
```

The API runs on `http://localhost:3000` by default.

## Scripts

```bash
npm run build
npm run test
npm run test:e2e
npm run start:dev
```

## Main Endpoints

### Auth

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

### Users

- `GET /users/profile`
- `PATCH /users/profile`

### Posts

- `POST /posts`
- `GET /posts?page=1&limit=10`
- `GET /posts/me?page=1&limit=10`
- `GET /posts/search?q=arquitectura&page=1&limit=10`
- `GET /posts/:id`
- `PATCH /posts/:id`
- `DELETE /posts/:id`

### Favorites

- `POST /favorites/:postId`
- `GET /favorites?page=1&limit=10`
- `GET /favorites/:postId/status`
- `DELETE /favorites/:postId`

## Postman

The collection and local environment are in:

- `tests/postman/OZIRAF Sprint 4.5.postman_collection.json`
- `tests/postman/OZIRAF Local.postman_environment.json`

Import both files into Postman and run the requests in order:

1. Register
2. Login
3. Profile
4. Posts
5. Favorites

The collection stores `token`, `user_id`, `post_id` and `favorite_id` automatically during the flow.

## Validation

The API uses a global validation pipe with:

- unknown fields rejected
- DTO validation enabled
- query/body transformation enabled

Current protections include trimmed text input, length limits, valid profile photo URLs, positive prices, paginated listings and public user responses without passwords.
