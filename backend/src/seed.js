import { inTransaction } from './db.js';

const demoOwner = {
  id: 'u1',
  email: 'u1@shareittoo.demo',
  profile: {
    displayName: 'Walid Chraibi',
    photoURL: 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=150&h=150&fit=crop&crop=face',
    city: 'Berlin',
    country: 'Deutschland',
    preferredLanguage: 'de-DE',
    emailVerified: true,
    phoneVerified: false,
    isVerified: true,
    isBanned: false,
    role: 'user',
    avgRating: 4.8,
    reviewCount: 12,
    languages: ['Deutsch'],
    interests: [],
  },
};

function listing({ id, title, description, categoryId, subcategory, price, photo, locationText, lat, lng, condition, maxDays, timesLent, delivery = false, pickup = false, express = false, maxDeliveryKm = null, maxPickupKm = null, cancellationPolicy = 'unified' }) {
  const createdAt = new Date(Date.now() - Number(id) * 60 * 60 * 1000).toISOString();
  return {
    id,
    ownerId: demoOwner.id,
    title,
    description,
    categoryId,
    subcategory,
    tags: [subcategory.toLowerCase(), 'berlin'],
    pricePerDay: price,
    currency: 'EUR',
    priceUnit: 'day',
    priceRaw: price,
    deposit: null,
    autoApplyDiscounts: true,
    longRentalDiscounts: [
      { days: 3, discountPercent: 10 },
      { days: 5, discountPercent: 20 },
      { days: 8, discountPercent: 30 },
    ],
    photos: [photo],
    locationText,
    lat,
    lng,
    geohash: `u${id}3${id}h${id}`,
    condition,
    minDays: 1,
    maxDays,
    createdAt,
    isActive: true,
    verificationStatus: 'approved',
    city: 'Berlin',
    country: 'Deutschland',
    status: 'active',
    endedAt: null,
    timesLent,
    offersDeliveryAtDropoff: delivery,
    offersPickupAtReturn: pickup,
    offersExpressAtDropoff: express,
    maxDeliveryKmAtDropoff: maxDeliveryKm,
    maxPickupKmAtReturn: maxPickupKm,
    cancellationPolicy,
  };
}

const demoListings = [
  listing({ id: '1', title: 'E-Bike Trekking 28"', description: 'Top gepflegt, Akku 500Wh, sofort verfügbar.', categoryId: 'cat9', subcategory: 'E-Bikes', price: 19, photo: 'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=800&h=800&fit=crop', locationText: 'Berlin-Mitte', lat: 52.52, lng: 13.405, condition: 'like-new', maxDays: 14, timesLent: 42, delivery: true, express: true, maxDeliveryKm: 10, cancellationPolicy: 'flexible' }),
  listing({ id: '2', title: 'Canon EOS R6 + 24-105mm', description: 'Spitzenzustand, inkl. 2 Akkus und Ladegerät.', categoryId: 'cat3', subcategory: 'Kameras', price: 45, photo: 'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?w=800&h=800&fit=crop', locationText: 'Berlin-Prenzlauer Berg', lat: 52.53, lng: 13.415, condition: 'like-new', maxDays: 7, timesLent: 31, pickup: true, maxPickupKm: 12, cancellationPolicy: 'moderate' }),
  listing({ id: '3', title: 'PlayStation 5 Digital Edition', description: 'Mit zweitem Controller, sehr leise, ideal fürs Wochenende.', categoryId: 'cat4', subcategory: 'Konsolen', price: 18, photo: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&h=800&fit=crop', locationText: 'Berlin-Friedrichshain', lat: 52.51, lng: 13.395, condition: 'good', maxDays: 10, timesLent: 27, cancellationPolicy: 'strict' }),
  listing({ id: '4', title: 'Dyson Akku-Staubsauger V11', description: 'Sehr sauber, mit Wandhalterung und Extra-Düsen.', categoryId: 'cat5', subcategory: 'Staubsauger', price: 12, photo: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&h=800&fit=crop', locationText: 'Berlin-Charlottenburg', lat: 52.535, lng: 13.39, condition: 'like-new', maxDays: 14, timesLent: 15, delivery: true, pickup: true, express: true, maxDeliveryKm: 5, maxPickupKm: 5, cancellationPolicy: 'moderate' }),
  listing({ id: '5', title: 'Bosch Bohrmaschine Professional', description: 'Robust, inkl. Koffer und Bohrer-Set.', categoryId: 'cat8', subcategory: 'Bohrmaschinen', price: 10, photo: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&h=800&fit=crop', locationText: 'Berlin-Neukölln', lat: 52.5, lng: 13.415, condition: 'good', maxDays: 10, timesLent: 22, delivery: true, express: true, maxDeliveryKm: 7, cancellationPolicy: 'flexible' }),
];

export async function seedPublicCatalog() {
  await inTransaction(async (client) => {
    await client.query(
      `INSERT INTO users (id, email, password_hash, profile)
       VALUES ($1, $2, NULL, $3::jsonb)
       ON CONFLICT (id) DO NOTHING`,
      [demoOwner.id, demoOwner.email, JSON.stringify(demoOwner.profile)],
    );

    for (const item of demoListings) {
      await client.query(
        `INSERT INTO listings (id, owner_id, payload, is_active, created_at)
         VALUES ($1, $2, $3::jsonb, true, $4::timestamptz)
         ON CONFLICT (id) DO NOTHING`,
        [item.id, demoOwner.id, JSON.stringify(item), item.createdAt],
      );
    }
  });
}
