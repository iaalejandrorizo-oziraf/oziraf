# OZIRAF Production Checklist

## Required before public launch

- Create Railway Pro project from the GitHub repository.
- Add Railway PostgreSQL and set `DATABASE_URL`.
- Deploy the backend service from the repository root.
- Set `JWT_SECRET` to a long random value.
- Set `CORS_ORIGIN` to the public web origins.
- Set `PUBLIC_WEB_URL` and `PUBLIC_API_URL`.
- Configure an email provider and set `RESEND_API_KEY` plus `MAIL_FROM`.
- Run `prisma migrate deploy` during backend startup.
- Build Flutter web with `OZIRAF_API_URL=https://api.oziraf.com`.
- Configure `oziraf.com` for web and `api.oziraf.com` for the backend.
- Enable SSL for both domains.
- Create the production admin user with a strong password.
- Test registration, login, password reset, email verification, post creation, media upload, reports, comments, admin moderation and session persistence.

## Strongly recommended before wider growth

- Move post media out of PostgreSQL into object storage such as Cloudflare R2, S3, Cloudinary or Railway volume-backed storage.
- Add database backups and restore testing.
- Add error monitoring.
- Add structured logs for auth, payments, reports and moderation actions.
- Require verified email before publishing posts.
- Add legal pages: terms, privacy, prohibited services, report process and refund/payment policy.
- Integrate payments for renewals instead of manual billing status updates.
- Add admin charts and daily movement reports.

## Current production gaps

- Password reset and email verification now call the mail layer, but need a real `RESEND_API_KEY` in production.
- Billing status exists for admin tracking, but there is no payment gateway yet.
- Media is still stored in PostgreSQL, which is acceptable for a small beta but not for growth.
- Docker and Railway configuration still need final values once the Railway project and domains exist.
