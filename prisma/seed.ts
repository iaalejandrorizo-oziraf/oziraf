import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.env.OZIRAF_ADMIN_EMAIL;
  const adminPassword = process.env.OZIRAF_ADMIN_PASSWORD;

  if (!adminEmail && !adminPassword) {
    console.log('No admin seed configured. Skipping admin user creation.');
    return;
  }

  if (!adminEmail || !adminPassword) {
    throw new Error(
      'OZIRAF_ADMIN_EMAIL and OZIRAF_ADMIN_PASSWORD must be set together.',
    );
  }

  if (adminPassword.length < 8) {
    throw new Error('OZIRAF_ADMIN_PASSWORD must be at least 8 characters.');
  }

  const hashedPassword = await bcrypt.hash(adminPassword, 10);

  const admin = await prisma.user.upsert({
    where: {
      email: adminEmail,
    },
    update: {
      password: hashedPassword,
      role: 'ADMIN',
      status: 'ACTIVE',
      emailVerified: true,
    },
    create: {
      email: adminEmail,
      password: hashedPassword,
      firstName: 'OZIRAF',
      lastName: 'Admin',
      role: 'ADMIN',
      status: 'ACTIVE',
      emailVerified: true,
    },
    select: {
      id: true,
      email: true,
      role: true,
      status: true,
      emailVerified: true,
    },
  });

  console.log(`Admin seed ready: ${admin.email} (${admin.id})`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
