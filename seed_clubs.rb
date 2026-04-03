# encoding: utf-8
require "net/http"
require "json"
require "uri"

SUPABASE_URL = "https://rizyqzjszaknzjboooow.supabase.co"
SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs"

hours24 = {"mon"=>"00:00-23:59","tue"=>"00:00-23:59","wed"=>"00:00-23:59","thu"=>"00:00-23:59","fri"=>"00:00-23:59","sat"=>"00:00-23:59","sun"=>"00:00-23:59"}
hoursDay = {"mon"=>"10:00-02:00","tue"=>"10:00-02:00","wed"=>"10:00-02:00","thu"=>"10:00-02:00","fri"=>"10:00-04:00","sat"=>"10:00-04:00","sun"=>"10:00-02:00"}
hoursShort = {"mon"=>"12:00-00:00","tue"=>"12:00-00:00","wed"=>"12:00-00:00","thu"=>"12:00-00:00","fri"=>"12:00-02:00","sat"=>"12:00-02:00","sun"=>"12:00-00:00"}

clubs = [
  # VIP (8)
  {n:"CyberArena VIP",a:"ul. Amira Temura, 15",lat:41.3111,lon:69.2797,t:"vip",pc:60,r:4.9,p:25000,ps:true,xb:true,vr:true,d:"Premium cyber-arena with VIP zones"},
  {n:"EliteZone Gaming",a:"ul. Navoi, 88",lat:41.3145,lon:69.2489,t:"vip",pc:45,r:4.8,p:22000,ps:true,xb:false,vr:true,d:"Elite gaming club with private cabins"},
  {n:"Royal Gamers Club",a:"pr. Shota Rustaveli, 22",lat:41.2867,lon:69.2201,t:"vip",pc:50,r:4.9,p:28000,ps:true,xb:true,vr:true,d:"RTX 4090, 360Hz monitors"},
  {n:"Platinum Hub",a:"ul. Babura, 40",lat:41.3200,lon:69.3050,t:"vip",pc:35,r:4.7,p:20000,ps:false,xb:true,vr:true,d:"Platinum standard VR rooms"},
  {n:"Legends Arena",a:"ul. Mustaqillik, 75",lat:41.3010,lon:69.2650,t:"vip",pc:55,r:4.8,p:24000,ps:true,xb:true,vr:false,d:"Weekly tournaments with prizes"},
  {n:"GG VIP Lounge",a:"ul. Nukusskaya, 33",lat:41.2955,lon:69.2350,t:"vip",pc:40,r:4.6,p:21000,ps:true,xb:false,vr:false,d:"Lounge zone with hookah and bar"},
  {n:"Apex Gaming VIP",a:"pr. Kosmonavtov, 12",lat:41.3280,lon:69.2180,t:"vip",pc:48,r:4.7,p:23000,ps:false,xb:true,vr:true,d:"8-station VR zone, streaming rooms"},
  {n:"Crown Esports",a:"ul. Furkata, 5",lat:41.2920,lon:69.2555,t:"vip",pc:42,r:4.9,p:26000,ps:true,xb:true,vr:true,d:"Professional esports center"},
  # Standard (16)
  {n:"GameZone Plus",a:"ul. Tarakkiyot, 18",lat:41.3050,lon:69.2920,t:"standard",pc:30,r:4.5,p:15000,ps:true,xb:false,vr:false,d:"RTX 3070, 144Hz monitors"},
  {n:"ProGaming Center",a:"Chilanzar, kv. 7",lat:41.2830,lon:69.2090,t:"standard",pc:40,r:4.4,p:14000,ps:false,xb:true,vr:false,d:"Professional equipment"},
  {n:"NetPlay Club",a:"ul. Bunyodkor, 55",lat:41.2780,lon:69.2350,t:"standard",pc:25,r:4.3,p:12000,ps:true,xb:false,vr:false,d:"Fast internet for MMORPG"},
  {n:"Pixel Station",a:"ul. Sebzor, 10",lat:41.3180,lon:69.2700,t:"standard",pc:35,r:4.6,p:16000,ps:true,xb:true,vr:false,d:"PS5 zone + PC arena"},
  {n:"Clutch Gaming",a:"Yunusabad, kv. 5",lat:41.3370,lon:69.2850,t:"standard",pc:28,r:4.2,p:13000,ps:false,xb:false,vr:false,d:"RTX 3060, 165Hz"},
  {n:"FragZone",a:"ul. Fergana Yuli, 100",lat:41.2700,lon:69.3100,t:"standard",pc:32,r:4.4,p:14000,ps:false,xb:true,vr:false,d:"Zone for FPS gamers"},
  {n:"Neon Arcade",a:"ul. Glinki, 8",lat:41.3100,lon:69.2400,t:"standard",pc:38,r:4.5,p:15000,ps:true,xb:false,vr:true,d:"Neon design, VR, retro arcades"},
  {n:"TurboLAN",a:"ul. Mirobod, 44",lat:41.3030,lon:69.2520,t:"standard",pc:26,r:4.1,p:11000,ps:false,xb:false,vr:false,d:"LAN club for tournaments"},
  {n:"RespawnPoint",a:"ul. Bektemir, 15",lat:41.2890,lon:69.3300,t:"standard",pc:30,r:4.3,p:13000,ps:true,xb:true,vr:false,d:"Cafe, PlayStation, Xbox, PC"},
  {n:"Digital Colosseum",a:"pr. Mirzo Ulugbeka, 50",lat:41.3390,lon:69.2610,t:"standard",pc:45,r:4.6,p:16000,ps:true,xb:true,vr:true,d:"Tournament stage for 200 viewers"},
  {n:"Level Up Cafe",a:"ul. Khamzy, 21",lat:41.2960,lon:69.2290,t:"standard",pc:20,r:4.4,p:12000,ps:true,xb:false,vr:false,d:"Gaming cafe with coffee"},
  {n:"Overclock Lab",a:"Katartal, kv. 4",lat:41.3250,lon:69.3200,t:"standard",pc:22,r:4.2,p:13000,ps:false,xb:false,vr:false,d:"Custom builds, water cooling"},
  {n:"Headshot Club",a:"ul. Oybek, 36",lat:41.3060,lon:69.2760,t:"standard",pc:34,r:4.5,p:15000,ps:false,xb:true,vr:false,d:"CS2 and Valorant club"},
  {n:"Ctrl+Play",a:"ul. Labzak, 9",lat:41.3150,lon:69.2580,t:"standard",pc:28,r:4.3,p:14000,ps:true,xb:false,vr:false,d:"28 PCs, PS5 zone"},
  {n:"GG WP Arena",a:"ul. Almazar, 67",lat:41.3320,lon:69.2400,t:"standard",pc:36,r:4.4,p:14000,ps:false,xb:true,vr:false,d:"Team scrim rooms"},
  {n:"NextLevel Hub",a:"ul. Amir Temur, 100",lat:41.3070,lon:69.2670,t:"standard",pc:30,r:4.3,p:13000,ps:true,xb:false,vr:false,d:"Next level gaming experience"},
  # Basic (16)
  {n:"ByteNet Cafe",a:"ul. Shahrisabzskaya, 20",lat:41.3000,lon:69.2450,t:"basic",pc:15,r:3.8,p:8000,ps:false,xb:false,vr:false,d:"GTX 1660, 75Hz"},
  {n:"QuickPlay",a:"Yangi Sergeli, 5",lat:41.2600,lon:69.2180,t:"basic",pc:18,r:3.9,p:7000,ps:false,xb:false,vr:false,d:"Quick, simple, affordable"},
  {n:"GameBit",a:"ul. Tinchliq, 42",lat:41.2750,lon:69.2600,t:"basic",pc:12,r:4.0,p:8000,ps:true,xb:false,vr:false,d:"PS4 + PC zone"},
  {n:"Net Zone",a:"ul. Kuyluk, 80",lat:41.2650,lon:69.3400,t:"basic",pc:20,r:3.7,p:6000,ps:false,xb:false,vr:false,d:"Budget club for Dota 2, CS2"},
  {n:"StartGame",a:"ul. Yalangach, 14",lat:41.2580,lon:69.2800,t:"basic",pc:16,r:4.1,p:9000,ps:false,xb:false,vr:false,d:"Affordable prices"},
  {n:"CyberCafe 24",a:"ul. Mirabad, 3",lat:41.2940,lon:69.2680,t:"basic",pc:14,r:3.6,p:6000,ps:false,xb:false,vr:false,d:"Open 24/7"},
  {n:"PlayBox",a:"ul. Sagbon, 22",lat:41.3090,lon:69.2150,t:"basic",pc:10,r:4.0,p:7000,ps:true,xb:false,vr:false,d:"Compact PS4 and PC club"},
  {n:"EasyGame",a:"ul. Chorsu, 55",lat:41.3270,lon:69.2330,t:"basic",pc:22,r:3.8,p:8000,ps:false,xb:false,vr:false,d:"22 PCs, Wi-Fi, drinks"},
  {n:"LAN Party",a:"ul. Farobiy, 18",lat:41.2820,lon:69.2050,t:"basic",pc:16,r:4.2,p:9000,ps:false,xb:false,vr:false,d:"Book the whole hall"},
  {n:"ClickNet",a:"ul. Oltin Tepa, 30",lat:41.2720,lon:69.2950,t:"basic",pc:18,r:3.9,p:7000,ps:false,xb:false,vr:false,d:"1 Gbit fiber optic"},
  {n:"GamerDen",a:"ul. Muqimiy, 48",lat:41.3020,lon:69.2320,t:"basic",pc:12,r:3.5,p:5000,ps:false,xb:false,vr:false,d:"Lowest prices in town"},
  {n:"NoobFriendly",a:"ul. Tarasa Shevchenko, 19",lat:41.3160,lon:69.2510,t:"basic",pc:15,r:4.0,p:8000,ps:false,xb:false,vr:false,d:"Free coaching for beginners"},
  {n:"Sprint Gaming",a:"ul. Chekhova, 7",lat:41.2850,lon:69.2750,t:"basic",pc:20,r:3.7,p:7000,ps:false,xb:false,vr:false,d:"20 PCs, fast internet"},
  {n:"PixelDust",a:"ul. Koratosh, 60",lat:41.2670,lon:69.2500,t:"basic",pc:10,r:4.1,p:8000,ps:true,xb:false,vr:false,d:"PS4 + retro games"},
  {n:"AFK Zone",a:"ul. Yangi Hayot, 35",lat:41.2550,lon:69.2300,t:"basic",pc:14,r:3.8,p:6000,ps:false,xb:false,vr:false,d:"Sofas, snacks, Wi-Fi"},
  {n:"CyberNest",a:"ul. Istiqlol, 99",lat:41.3400,lon:69.2700,t:"basic",pc:16,r:3.9,p:7000,ps:false,xb:false,vr:false,d:"Cozy atmosphere, coffee"},
]

rows = clubs.map do |c|
  wh = c[:t] == "vip" ? hours24 : c[:t] == "standard" ? hoursDay : hoursShort
  {
    "name" => c[:n], "address" => c[:a], "lat" => c[:lat], "lon" => c[:lon],
    "tier" => c[:t], "pc_count" => c[:pc], "rating" => c[:r],
    "has_playstation" => c[:ps] || false,
    "has_xbox" => c[:xb] || false, "has_vr" => c[:vr] || false,
    "photos" => [], "working_hours" => wh,
    "status" => "active",
  }
end

uri = URI("#{SUPABASE_URL}/rest/v1/clubs")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
req = Net::HTTP::Post.new(uri)
# First login to get authenticated token
login_uri = URI("#{SUPABASE_URL}/auth/v1/token?grant_type=password")
login_http = Net::HTTP.new(login_uri.host, login_uri.port)
login_http.use_ssl = true
login_req = Net::HTTP::Post.new(login_uri)
login_req["apikey"] = SUPABASE_ANON
login_req["Content-Type"] = "application/json"
login_req.body = '{"email":"demo@gamepass.uz","password":"Demo1234!"}'
login_res = login_http.request(login_req)
token = JSON.parse(login_res.body)["access_token"]
puts "Logged in, token: #{token[0..30]}..."

req["apikey"] = SUPABASE_ANON
req["Authorization"] = "Bearer #{token}"
req["Content-Type"] = "application/json"
req["Prefer"] = "return=representation"
req.body = JSON.generate(rows)

puts "Inserting #{rows.length} clubs..."
res = http.request(req)
if res.code.to_i >= 200 && res.code.to_i < 300
  data = JSON.parse(res.body)
  puts "SUCCESS: Inserted #{data.length} clubs!"
  data.each { |c| puts "  [#{c["tier"]}] #{c["name"]}" }
else
  puts "ERROR #{res.code}: #{res.body}"
end
