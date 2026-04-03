// Seed 40 clubs across Tashkent with different tiers
const SUPABASE_URL = 'https://rizyqzjszaknzjboooow.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs';

const clubs = [
  // === VIP клубы (8) ===
  { name: "CyberArena VIP", address: "ул. Амира Темура, 15", lat: 41.3111, lon: 69.2797, tier: "vip", pc_count: 60, rating: 4.9, price_per_hour: 25000, has_playstation: true, has_xbox: true, has_vr: true, description: "Премиум кибер-арена с VIP-зонами, лаунж-баром и стриминг-студией.", contact_phone: "+998901110001", contact_telegram: "@cyberarena_vip" },
  { name: "EliteZone Gaming", address: "ул. Навои, 88", lat: 41.3145, lon: 69.2489, tier: "vip", pc_count: 45, rating: 4.8, price_per_hour: 22000, has_playstation: true, has_xbox: false, has_vr: true, description: "Элитный игровой клуб с индивидуальными кабинами и массажными креслами." },
  { name: "Royal Gamers Club", address: "просп. Шота Руставели, 22", lat: 41.2867, lon: 69.2201, tier: "vip", pc_count: 50, rating: 4.9, price_per_hour: 28000, has_playstation: true, has_xbox: true, has_vr: true, description: "Королевский уровень гейминга. RTX 4090, 360Hz мониторы." },
  { name: "Platinum Hub", address: "ул. Бабура, 40", lat: 41.3200, lon: 69.3050, tier: "vip", pc_count: 35, rating: 4.7, price_per_hour: 20000, has_playstation: false, has_xbox: true, has_vr: true, description: "Платиновый стандарт игровых клубов. Отдельные VR-комнаты." },
  { name: "Legends Arena", address: "ул. Мустакиллик, 75", lat: 41.3010, lon: 69.2650, tier: "vip", pc_count: 55, rating: 4.8, price_per_hour: 24000, has_playstation: true, has_xbox: true, has_vr: false, description: "Арена для легенд. Турниры каждую неделю с призовым фондом." },
  { name: "GG VIP Lounge", address: "ул. Нукусская, 33", lat: 41.2955, lon: 69.2350, tier: "vip", pc_count: 40, rating: 4.6, price_per_hour: 21000, has_playstation: true, has_xbox: false, has_vr: false, description: "Лаунж-зона для комфортной игры. Кальян, бар, PlayStation 5." },
  { name: "Apex Gaming VIP", address: "просп. Космонавтов, 12", lat: 41.3280, lon: 69.2180, tier: "vip", pc_count: 48, rating: 4.7, price_per_hour: 23000, has_playstation: false, has_xbox: true, has_vr: true, description: "Топовое железо, VR-зона на 8 станций, стриминг-комнаты." },
  { name: "Crown Esports", address: "ул. Фурката, 5", lat: 41.2920, lon: 69.2555, tier: "vip", pc_count: 42, rating: 4.9, price_per_hour: 26000, has_playstation: true, has_xbox: true, has_vr: true, description: "Профессиональный киберспортивный центр с тренерами." },

  // === Standard клубы (16) ===
  { name: "GameZone Plus", address: "ул. Тараккиёт, 18", lat: 41.3050, lon: 69.2920, tier: "standard", pc_count: 30, rating: 4.5, price_per_hour: 15000, has_playstation: true, has_xbox: false, has_vr: false, description: "Уютный клуб с хорошим оборудованием. RTX 3070, 144Hz." },
  { name: "ProGaming Center", address: "ул. Чиланзар, кв. 7", lat: 41.2830, lon: 69.2090, tier: "standard", pc_count: 40, rating: 4.4, price_per_hour: 14000, has_playstation: false, has_xbox: true, has_vr: false, description: "Профессиональное оборудование для серьёзных геймеров." },
  { name: "NetPlay Club", address: "ул. Бунёдкор, 55", lat: 41.2780, lon: 69.2350, tier: "standard", pc_count: 25, rating: 4.3, price_per_hour: 12000, has_playstation: true, has_xbox: false, has_vr: false, description: "Сетевой клуб с быстрым интернетом. Идеально для MMORPG." },
  { name: "Pixel Station", address: "ул. Себзор, 10", lat: 41.3180, lon: 69.2700, tier: "standard", pc_count: 35, rating: 4.6, price_per_hour: 16000, has_playstation: true, has_xbox: true, has_vr: false, description: "Современная игровая станция. PS5 зона + PC арена." },
  { name: "Clutch Gaming", address: "ул. Юнусабад, кв. 5", lat: 41.3370, lon: 69.2850, tier: "standard", pc_count: 28, rating: 4.2, price_per_hour: 13000, has_playstation: false, has_xbox: false, has_vr: false, description: "Чистый PC-гейминг. RTX 3060, 165Hz мониторы." },
  { name: "FragZone", address: "ул. Фергана Йули, 100", lat: 41.2700, lon: 69.3100, tier: "standard", pc_count: 32, rating: 4.4, price_per_hour: 14000, has_playstation: false, has_xbox: true, has_vr: false, description: "Зона для шутеров. Специальные мышки и наушники." },
  { name: "Neon Arcade", address: "ул. Глинки, 8", lat: 41.3100, lon: 69.2400, tier: "standard", pc_count: 38, rating: 4.5, price_per_hour: 15000, has_playstation: true, has_xbox: false, has_vr: true, description: "Неоновый дизайн, VR-зона, ретро-аркадные автоматы." },
  { name: "TurboLAN", address: "ул. Миробод, 44", lat: 41.3030, lon: 69.2520, tier: "standard", pc_count: 26, rating: 4.1, price_per_hour: 11000, has_playstation: false, has_xbox: false, has_vr: false, description: "Быстрый LAN-клуб для турниров. Гигабитный интернет." },
  { name: "RespawnPoint", address: "ул. Бектемир, 15", lat: 41.2890, lon: 69.3300, tier: "standard", pc_count: 30, rating: 4.3, price_per_hour: 13000, has_playstation: true, has_xbox: true, has_vr: false, description: "Точка респавна. Кафе, PlayStation, Xbox, PC." },
  { name: "Digital Colosseum", address: "просп. Мирзо Улугбека, 50", lat: 41.3390, lon: 69.2610, tier: "standard", pc_count: 45, rating: 4.6, price_per_hour: 16000, has_playstation: true, has_xbox: true, has_vr: true, description: "Цифровой колизей. Сцена для турниров на 200 зрителей." },
  { name: "Level Up Cafe", address: "ул. Хамзы, 21", lat: 41.2960, lon: 69.2290, tier: "standard", pc_count: 20, rating: 4.4, price_per_hour: 12000, has_playstation: true, has_xbox: false, has_vr: false, description: "Игровое кафе. Кофе, сэндвичи и хороший гейминг." },
  { name: "Overclock Lab", address: "ул. Катартал, кв. 4", lat: 41.3250, lon: 69.3200, tier: "standard", pc_count: 22, rating: 4.2, price_per_hour: 13000, has_playstation: false, has_xbox: false, has_vr: false, description: "Лаборатория разгона. Кастомные сборки, водяное охлаждение." },
  { name: "Headshot Club", address: "ул. Ойбек, 36", lat: 41.3060, lon: 69.2760, tier: "standard", pc_count: 34, rating: 4.5, price_per_hour: 15000, has_playstation: false, has_xbox: true, has_vr: false, description: "Клуб для любителей CS2 и Valorant. Турниры каждые выходные." },
  { name: "Ctrl+Play", address: "ул. Лабзак, 9", lat: 41.3150, lon: 69.2580, tier: "standard", pc_count: 28, rating: 4.3, price_per_hour: 14000, has_playstation: true, has_xbox: false, has_vr: false, description: "Ctrl+Play — управляй игрой! 28 мощных PC, PlayStation 5 зона." },
  { name: "GG WP Arena", address: "ул. Алмазар, 67", lat: 41.3320, lon: 69.2400, tier: "standard", pc_count: 36, rating: 4.4, price_per_hour: 14000, has_playstation: false, has_xbox: true, has_vr: false, description: "GG WP! Арена для командных игр. Комнаты для скримов." },

  // === Basic клубы (16) ===
  { name: "ByteNet Cafe", address: "ул. Шахрисабзская, 20", lat: 41.3000, lon: 69.2450, tier: "basic", pc_count: 15, rating: 3.8, price_per_hour: 8000, has_playstation: false, has_xbox: false, has_vr: false, description: "Доступный интернет-клуб с играми. GTX 1660, 75Hz." },
  { name: "QuickPlay", address: "ул. Янги Сергели, 5", lat: 41.2600, lon: 69.2180, tier: "basic", pc_count: 18, rating: 3.9, price_per_hour: 7000, has_playstation: false, has_xbox: false, has_vr: false, description: "Быстро, просто, доступно. 18 компьютеров для игр." },
  { name: "GameBit", address: "ул. Тинчлик, 42", lat: 41.2750, lon: 69.2600, tier: "basic", pc_count: 12, rating: 4.0, price_per_hour: 8000, has_playstation: true, has_xbox: false, has_vr: false, description: "Маленький уютный клуб. PS4 + PC зона." },
  { name: "Net Zone", address: "ул. Куйлюк, 80", lat: 41.2650, lon: 69.3400, tier: "basic", pc_count: 20, rating: 3.7, price_per_hour: 6000, has_playstation: false, has_xbox: false, has_vr: false, description: "Бюджетный клуб с хорошим интернетом. Dota 2, CS2." },
  { name: "StartGame", address: "ул. Ялангач, 14", lat: 41.2580, lon: 69.2800, tier: "basic", pc_count: 16, rating: 4.1, price_per_hour: 9000, has_playstation: false, has_xbox: false, has_vr: false, description: "Начни играть! Доступные цены, хорошее оборудование." },
  { name: "CyberCafe 24", address: "ул. Мирабад, 3", lat: 41.2940, lon: 69.2680, tier: "basic", pc_count: 14, rating: 3.6, price_per_hour: 6000, has_playstation: false, has_xbox: false, has_vr: false, description: "Работаем 24/7. Ночные тарифы от 4000 UZS/ч." },
  { name: "PlayBox", address: "ул. Сагбон, 22", lat: 41.3090, lon: 69.2150, tier: "basic", pc_count: 10, rating: 4.0, price_per_hour: 7000, has_playstation: true, has_xbox: false, has_vr: false, description: "Компактный клуб с PlayStation 4 и PC." },
  { name: "EasyGame", address: "ул. Чорсу, 55", lat: 41.3270, lon: 69.2330, tier: "basic", pc_count: 22, rating: 3.8, price_per_hour: 8000, has_playstation: false, has_xbox: false, has_vr: false, description: "Простой и удобный. 22 PC, Wi-Fi, напитки." },
  { name: "LAN Party", address: "ул. Фаробий, 18", lat: 41.2820, lon: 69.2050, tier: "basic", pc_count: 16, rating: 4.2, price_per_hour: 9000, has_playstation: false, has_xbox: false, has_vr: false, description: "Клуб для LAN-вечеринок. Бронируйте весь зал!" },
  { name: "ClickNet", address: "ул. Олтин Тепа, 30", lat: 41.2720, lon: 69.2950, tier: "basic", pc_count: 18, rating: 3.9, price_per_hour: 7000, has_playstation: false, has_xbox: false, has_vr: false, description: "Интернет-клуб нового поколения. Оптоволокно 1 Гбит." },
  { name: "GamerDen", address: "ул. Мукимий, 48", lat: 41.3020, lon: 69.2320, tier: "basic", pc_count: 12, rating: 3.5, price_per_hour: 5000, has_playstation: false, has_xbox: false, has_vr: false, description: "Самые низкие цены в городе! Играй от 5000 UZS/ч." },
  { name: "NoobFriendly", address: "ул. Тараса Шевченко, 19", lat: 41.3160, lon: 69.2510, tier: "basic", pc_count: 15, rating: 4.0, price_per_hour: 8000, has_playstation: false, has_xbox: false, has_vr: false, description: "Дружелюбная атмосфера. Обучение новичков бесплатно!" },
  { name: "Sprint Gaming", address: "ул. Чехова, 7", lat: 41.2850, lon: 69.2750, tier: "basic", pc_count: 20, rating: 3.7, price_per_hour: 7000, has_playstation: false, has_xbox: false, has_vr: false, description: "Спринт к победе! 20 ПК, быстрый интернет." },
  { name: "PixelDust", address: "ул. Коратош, 60", lat: 41.2670, lon: 69.2500, tier: "basic", pc_count: 10, rating: 4.1, price_per_hour: 8000, has_playstation: true, has_xbox: false, has_vr: false, description: "Пиксели и пыль — романтика гейминга. PS4 + ретро-игры." },
  { name: "AFK Zone", address: "ул. Янги Хаёт, 35", lat: 41.2550, lon: 69.2300, tier: "basic", pc_count: 14, rating: 3.8, price_per_hour: 6000, has_playstation: false, has_xbox: false, has_vr: false, description: "Зона AFK — отдыхай и играй. Диваны, снеки, Wi-Fi." },
  { name: "CyberNest", address: "ул. Истиклол, 99", lat: 41.3400, lon: 69.2700, tier: "basic", pc_count: 16, rating: 3.9, price_per_hour: 7000, has_playstation: false, has_xbox: false, has_vr: false, description: "Уютное гнездо геймера. Тёплая атмосфера, хороший кофе." },
];

// Working hours template
const hours24 = { mon: "00:00-23:59", tue: "00:00-23:59", wed: "00:00-23:59", thu: "00:00-23:59", fri: "00:00-23:59", sat: "00:00-23:59", sun: "00:00-23:59" };
const hoursDay = { mon: "10:00-02:00", tue: "10:00-02:00", wed: "10:00-02:00", thu: "10:00-02:00", fri: "10:00-04:00", sat: "10:00-04:00", sun: "10:00-02:00" };
const hoursShort = { mon: "12:00-00:00", tue: "12:00-00:00", wed: "12:00-00:00", thu: "12:00-00:00", fri: "12:00-02:00", sat: "12:00-02:00", sun: "12:00-00:00" };

async function seed() {
  // Use fetch directly to Supabase REST API
  const headers = {
    'apikey': SUPABASE_ANON,
    'Authorization': 'Bearer ' + SUPABASE_ANON,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
  };

  const rows = clubs.map((c, i) => ({
    name: c.name,
    address: c.address,
    lat: c.lat,
    lon: c.lon,
    tier: c.tier,
    pc_count: c.pc_count,
    rating: c.rating,
    price_per_hour: c.price_per_hour,
    has_playstation: c.has_playstation || false,
    has_xbox: c.has_xbox || false,
    has_vr: c.has_vr || false,
    description: c.description || null,
    contact_phone: c.contact_phone || null,
    contact_telegram: c.contact_telegram || null,
    photos: [],
    working_hours: c.tier === 'vip' ? hours24 : c.tier === 'standard' ? hoursDay : hoursShort,
    status: 'active',
    review_count: Math.floor(Math.random() * 200) + 5,
  }));

  console.log('Inserting', rows.length, 'clubs...');

  const res = await fetch(SUPABASE_URL + '/rest/v1/clubs', {
    method: 'POST',
    headers: headers,
    body: JSON.stringify(rows)
  });

  if (!res.ok) {
    const err = await res.text();
    console.error('Error:', res.status, err);
  } else {
    const data = await res.json();
    console.log('Inserted', data.length, 'clubs successfully!');
    data.forEach(c => console.log(`  [${c.tier}] ${c.name} — ${c.address}`));
  }
}

seed().catch(console.error);
