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
    phone: '3330001100',
    whatsapp: '3330001100',
    instagramUrl: 'https://instagram.com/oziraf.demo.arquitectura',
    facebookUrl: 'https://facebook.com/oziraf.demo.arquitectura',
    websiteUrl: 'https://oziraf.local/arquitectura',
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
        address: 'Colonia Americana, Guadalajara, Jalisco',
        latitude: 20.6748,
        longitude: -103.3586,
        imageUrls: [
          'https://placehold.co/900x600/e7f0df/17211b?text=Remodelacion+OZIRAF',
          'https://placehold.co/900x600/f6f7f4/17211b?text=Antes+y+Despues',
        ],
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
    phone: '3330002200',
    whatsapp: '3330002200',
    instagramUrl: 'https://instagram.com/oziraf.demo.electricidad',
    facebookUrl: 'https://facebook.com/oziraf.demo.electricidad',
    websiteUrl: 'https://oziraf.local/electricidad',
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
        address: 'Chapalita, Zapopan, Jalisco',
        latitude: 20.6736,
        longitude: -103.4055,
        imageUrls: [
          'https://placehold.co/900x600/e7f0df/17211b?text=Instalacion+Electrica',
          'https://placehold.co/900x600/f6f7f4/17211b?text=Revision+de+Cargas',
        ],
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
    phone: '8130003300',
    whatsapp: '8130003300',
    instagramUrl: 'https://instagram.com/oziraf.demo.limpieza',
    facebookUrl: 'https://facebook.com/oziraf.demo.limpieza',
    websiteUrl: 'https://oziraf.local/limpieza',
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
        address: 'Centro, Monterrey, Nuevo Leon',
        latitude: 25.6866,
        longitude: -100.3161,
        imageUrls: [
          'https://placehold.co/900x600/e7f0df/17211b?text=Limpieza+Profunda',
          'https://placehold.co/900x600/f6f7f4/17211b?text=Servicio+para+Mudanza',
        ],
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
        phone: provider.phone,
        whatsapp: provider.whatsapp,
        instagramUrl: provider.instagramUrl,
        facebookUrl: provider.facebookUrl,
        websiteUrl: provider.websiteUrl,
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
        phone: provider.phone,
        whatsapp: provider.whatsapp,
        instagramUrl: provider.instagramUrl,
        facebookUrl: provider.facebookUrl,
        websiteUrl: provider.websiteUrl,
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
