const API_URL = process.env.OZIRAF_API_URL ?? 'http://localhost:3000';
const stamp = new Date().toISOString().replace(/\D/g, '');
const password = 'Password123';

async function api(method, path, body, token) {
  const response = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${method} ${path} failed: ${response.status} ${text}`);
  }

  return response.json();
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  const providerEmail = `provider+${stamp}@oziraf.test`;
  const clientEmail = `client+${stamp}@oziraf.test`;

  await api('GET', '/health');

  await api('POST', '/auth/register', {
    email: providerEmail,
    password,
    firstName: 'Proveedor',
    lastName: 'Smoke',
    city: 'Guadalajara',
    state: 'Jalisco',
    profession: 'Tecnico especializado',
  });

  await api('POST', '/auth/register', {
    email: clientEmail,
    password,
    firstName: 'Cliente',
    lastName: 'Smoke',
    city: 'Zapopan',
    state: 'Jalisco',
    profession: 'Cliente',
  });

  const providerLogin = await api('POST', '/auth/login', {
    email: providerEmail,
    password,
  });
  const clientLogin = await api('POST', '/auth/login', {
    email: clientEmail,
    password,
  });

  assert(providerLogin.access_token, 'Provider login did not return a token');
  assert(clientLogin.access_token, 'Client login did not return a token');

  const providerToken = providerLogin.access_token;
  const clientToken = clientLogin.access_token;

  const profile = await api(
    'PATCH',
    '/users/profile',
    {
      phone: '3312345678',
      whatsapp: '3312345678',
      instagramUrl: 'https://instagram.com/oziraf.smoke',
      facebookUrl: 'https://facebook.com/oziraf.smoke',
      websiteUrl: 'https://oziraf.local/smoke',
      description: 'Proveedor validado por smoke test.',
    },
    providerToken,
  );
  assert(
    !Object.hasOwn(profile, 'password'),
    'Profile response leaked password',
  );
  assert(profile.instagramUrl, 'Profile social links were not saved');

  const post = await api(
    'POST',
    '/posts',
    {
      title: `Servicio smoke ${stamp}`,
      description: 'Servicio de prueba para validar el flujo MVP de OZIRAF.',
      category: 'Mantenimiento',
      country: 'Mexico',
      state: 'Jalisco',
      city: 'Guadalajara',
      neighborhood: 'Centro',
      address: 'Centro, Guadalajara, Jalisco',
      latitude: 20.6767,
      longitude: -103.3475,
      imageUrls: [
        'https://placehold.co/900x600/e7f0df/17211b?text=Smoke+OZIRAF',
      ],
      price: 700,
    },
    providerToken,
  );
  assert(post.id, 'Post was not created');
  assert(post.imageUrls?.length === 1, 'Post image URLs were not saved');

  await api('POST', `/favorites/${post.id}`, undefined, clientToken);
  const favoriteStatus = await api(
    'GET',
    `/favorites/${post.id}/status`,
    undefined,
    clientToken,
  );
  assert(favoriteStatus.isFavorite === true, 'Favorite status was not true');

  const lead = await api(
    'POST',
    `/contacts/posts/${post.id}`,
    {
      message: 'Hola, quiero cotizar este servicio de prueba.',
    },
    clientToken,
  );
  assert(lead.id, 'Lead was not created');

  const report = await api(
    'POST',
    `/reports/posts/${post.id}`,
    {
      reason: 'OTHER',
      details: 'Smoke test report.',
    },
    clientToken,
  );
  assert(report.id, 'Report was not created');

  const review = await api(
    'POST',
    `/reviews/posts/${post.id}`,
    {
      rating: 5,
      comment: 'Excelente atencion de prueba.',
    },
    clientToken,
  );
  assert(review.rating === 5, 'Review was not created');

  const reviews = await api(
    'GET',
    `/reviews/posts/${post.id}`,
    undefined,
    clientToken,
  );
  assert(
    reviews.data.some((item) => item.id === review.id),
    'Review list is missing review',
  );

  const leads = await api(
    'GET',
    '/contacts/leads?page=1&limit=10',
    undefined,
    providerToken,
  );
  assert(
    leads.data.some((item) => item.id === lead.id),
    'Provider did not receive lead',
  );

  const readLead = await api(
    'PATCH',
    `/contacts/leads/${lead.id}/status`,
    {
      status: 'READ',
    },
    providerToken,
  );
  assert(readLead.status === 'READ', 'Lead was not marked as READ');

  const myPosts = await api(
    'GET',
    '/posts/me?page=1&limit=10',
    undefined,
    providerToken,
  );
  assert(
    myPosts.data.some((item) => item.id === post.id),
    'Provider post list is missing post',
  );

  const stats = await api('GET', '/posts/me/stats', undefined, providerToken);
  assert(
    stats.total >= 1 && stats.active >= 1,
    'Provider stats were not updated',
  );

  const pausedPost = await api(
    'PATCH',
    `/posts/${post.id}/status`,
    {
      status: 'INACTIVE',
    },
    providerToken,
  );
  assert(pausedPost.status === 'INACTIVE', 'Post was not paused');

  console.log(
    JSON.stringify(
      {
        ok: true,
        apiUrl: API_URL,
        providerEmail,
        clientEmail,
        postId: post.id,
        leadId: lead.id,
        reportId: report.id,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
