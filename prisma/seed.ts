import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();
const demoPassword = 'Password123';

const demoProviders = [
  {
    email: 'mariana.arq@oziraf.local',
    firstName: 'Mariana',
    lastName: 'Lopez',
    profession: 'Arquitecta',
    city: 'Guadalajara',
    state: 'Jalisco',
    description:
      'Remodelaciones residenciales con presupuesto claro y seguimiento por etapas.',
    posts: [
      {
        title: 'Remodelacion integral de vivienda',
        description:
          'Diseno, presupuesto y ejecucion de remodelaciones para casas y departamentos.',
        category: 'Construccion',
        country: 'Mexico',
        state: 'Jalisco',
        city: 'Guadalajara',
        neighborhood: 'Americana',
        price: 2500,
      },
    ],
  },
  {
    email: 'carlos.electricidad@oziraf.local',
    firstName: 'Carlos',
    lastName: 'Mendez',
    profession: 'Electricista certificado',
    city: 'Zapopan',
    state: 'Jalisco',
    description:
      'Instalaciones, reparaciones y revision de cargas electricas para hogar y negocio.',
    posts: [
      {
        title: 'Electricista certificado para hogar',
        description:
          'Instalaciones, reparaciones y revision de cargas electricas con agenda flexible.',
        category: 'Tecnicos',
        country: 'Mexico',
        state: 'Jalisco',
        city: 'Zapopan',
        neighborhood: 'Chapalita',
        price: 650,
      },
    ],
  },
  {
    email: 'sofia.limpieza@oziraf.local',
    firstName: 'Sofia',
    lastName: 'Ramos',
    profession: 'Servicios de limpieza',
    city: 'Monterrey',
    state: 'Nuevo Leon',
    description:
      'Equipo de limpieza para mudanzas, oficinas pequenas y departamentos amueblados.',
    posts: [
      {
        title: 'Limpieza profunda para mudanza',
        description:
          'Equipo de limpieza para casas, oficinas pequenas y departamentos amueblados.',
        category: 'Limpieza',
        country: 'Mexico',
        state: 'Nuevo Leon',
        city: 'Monterrey',
        neighborhood: 'Centro',
        price: 1200,
      },
    ],
  },
];

async function main() {
  const adminEmail = process.env.OZIRAF_ADMIN_EMAIL;
  const adminPassword = process.env.OZIRAF_ADMIN_PASSWORD;

  await seedAdmin(adminEmail, adminPassword);
  await seedDemoMarketplace();
}

async function seedAdmin(adminEmail?: string, adminPassword?: string) {
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

async function seedDemoMarketplace() {
  const hashedPassword = await bcrypt.hash(demoPassword, 10);

  for (const provider of demoProviders) {
    const user = await prisma.user.upsert({
      where: {
        email: provider.email,
      },
      update: {
        firstName: provider.firstName,
        lastName: provider.lastName,
        profession: provider.profession,
        city: provider.city,
        state: provider.state,
        description: provider.description,
        status: 'ACTIVE',
        emailVerified: true,
      },
      create: {
        email: provider.email,
        password: hashedPassword,
        firstName: provider.firstName,
        lastName: provider.lastName,
        profession: provider.profession,
        city: provider.city,
        state: provider.state,
        description: provider.description,
        status: 'ACTIVE',
        emailVerified: true,
      },
      select: {
        id: true,
        email: true,
      },
    });

    for (const post of provider.posts) {
      const existingPost = await prisma.post.findFirst({
        where: {
          userId: user.id,
          title: post.title,
          status: {
            not: 'DELETED',
          },
        },
        select: {
          id: true,
        },
      });

      if (existingPost) {
        await prisma.post.update({
          where: {
            id: existingPost.id,
          },
          data: {
            ...post,
            status: 'ACTIVE',
          },
        });
        continue;
      }

      await prisma.post.create({
        data: {
          ...post,
          status: 'ACTIVE',
          userId: user.id,
        },
      });
    }

    console.log(`Demo provider ready: ${user.email}`);
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
