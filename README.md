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
- `PATCH /auth/password`
- `POST /auth/password-reset/request`
- `POST /auth/password-reset/confirm`

### Users

- `GET /users/profile`
- `PATCH /users/profile`
- `GET /users/admin?page=1&limit=10&status=ACTIVE&role=USER`
- `PATCH /users/admin/:id/status`

### Posts

- `POST /posts`
- `GET /posts?page=1&limit=10&sortBy=createdAt&sortOrder=desc`
- `GET /posts/me/stats`
- `GET /posts/me?page=1&limit=10&sortBy=createdAt&sortOrder=desc&status=INACTIVE`
- `GET /posts/search?q=arquitectura&minPrice=1000&maxPrice=5000&page=1&limit=10&sortBy=createdAt&sortOrder=desc`
- `GET /posts/filters`
- `GET /posts/:id`
- `PATCH /posts/:id/status`
- `PATCH /posts/:id`
- `DELETE /posts/:id`

### Favorites

- `POST /favorites/:postId`
- `GET /favorites?page=1&limit=10`
- `GET /favorites/:postId/status`
- `DELETE /favorites/:postId`

### Contacts

- `POST /contacts/posts/:postId`
- `GET /contacts/leads?page=1&limit=10&status=NEW`
- `PATCH /contacts/leads/:id/status`

### Reports

- `POST /reports/posts/:postId`
- `GET /reports/me`
- `GET /reports/admin?page=1&limit=10&status=OPEN`
- `PATCH /reports/admin/:id/status`

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
Public post listings return only active posts. Users can pause and reactivate their own posts with `ACTIVE` and `INACTIVE`. Deleting a post marks it as `DELETED` instead of removing the row. Users cannot add their own posts to favorites or contact their own posts.

## Paginated Responses

Paginated endpoints return:

```json
{
  "data": [],
  "page": 1,
  "limit": 10,
  "total": 0,
  "totalPages": 0
}
```
