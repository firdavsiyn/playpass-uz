#!/usr/bin/env python3
"""Insert missing clubs with correct tier values"""
import json, subprocess

API_URL = "https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query"
TOKEN = "sbp_856e4068bebec50c18b41dac00fd30695444208b"

def run_sql(sql):
    payload = json.dumps({"query": sql})
    r = subprocess.run(["curl","-s","-X","POST",API_URL,"-H",f"Authorization: Bearer {TOKEN}","-H","Content-Type: application/json","-d",payload], capture_output=True, text=True, timeout=30)
    return r.stdout

WH24 = '{"mon":{"open":"00:00","close":"23:59"},"tue":{"open":"00:00","close":"23:59"},"wed":{"open":"00:00","close":"23:59"},"thu":{"open":"00:00","close":"23:59"},"fri":{"open":"00:00","close":"23:59"},"sat":{"open":"00:00","close":"23:59"},"sun":{"open":"00:00","close":"23:59"}}'

# Missing clubs - using 'vip' instead of 'premium'
missing = [
    ("COLIZEUM", "БЦ GC, Ниёзбек Йули, 30, -1 этаж", 41.321257, 69.295967, 80, 5.0, "vip", True, False, "Крупнейшая сеть киберспортивных клубов.", 20000, 159, "+998 90-900-96-55", "@colizeum_uz"),
    ("Meta Gaming", "Кашгар (Ц-4) ж/м, Юнусабадский район", 41.311392, 69.276212, 80, 4.1, "vip", True, False, "80 ПК, PS5, VIP-зоны.", 18000, 12, "+998 33-033-33-63", "@meta_gaming_uz"),
    ("CyberX", "Юнусабад 4-й квартал, 4Б", 41.354200, 69.284100, 45, 5.0, "vip", False, False, "Твой портал в киберпространство!", 15000, 189, "+998 33-800-51-10", None),
    ("Dark Zone E-sport (Лабзак)", "ул. Лабзак, 112, цокольный этаж", 41.335652, 69.265701, 50, 4.8, "vip", False, False, "Крупнейшая сеть киберклубов. 9 филиалов.", 15000, 76, "+998 33-125-33-33", "@darkzone_esport"),
    ("Dark Zone E-sport (Юнусабад)", "Юнусабад 14-й квартал, 71", 41.369867, 69.310496, 40, 4.0, "standard", False, False, "Филиал Dark Zone в Юнусабаде.", 15000, 35, "+998 33-125-33-33", "@darkzone_esport"),
    ("Dark Zone E-sport (Мирзо Улугбек)", "Мирзо Улугбека, 91а", 41.346227, 69.346418, 40, 3.9, "standard", False, False, "Филиал Dark Zone.", 15000, 12, "+998 33-125-33-33", "@darkzone_esport"),
    ("Dark Zone E-sport (Кадышева)", "ул. Авиасозлар, 128", 41.285400, 69.340200, 35, 4.2, "standard", False, False, "Филиал Dark Zone в Яшнабаде.", 15000, 20, "+998 33-125-33-33", "@darkzone_esport"),
    ("Dark Zone E-sport (Паркентский)", "ул. Паркент, М.Риёзи, 76", 41.320100, 69.352300, 35, 4.0, "standard", False, False, "Филиал Dark Zone.", 15000, 15, "+998 33-125-33-33", "@darkzone_esport"),
    ("Dark Zone E-sport (Чимган)", "Мирзо Улугбека, 92", 41.347100, 69.345600, 35, 4.1, "standard", False, False, "Филиал Dark Zone.", 15000, 10, "+998 33-125-33-33", "@darkzone_esport"),
    ("FIDANZA Game Club (Кадышева)", "Бешарыкская, Авиасозлар-2, 34А", 41.283200, 69.332400, 150, 4.5, "vip", True, False, "23 VIP-кабины, PS5, караоке. 435 ПК в сети.", 18000, 50, "+998 95-411-00-00", "@fidanzagameclub"),
    ("FIDANZA Game Club (Себзар)", "ул. А. Кадыри, Джангох, 10Б", 41.332500, 69.252300, 140, 4.3, "vip", True, False, "Филиал FIDANZA. ПК, PS5, VIP.", 18000, 30, "+998 95-411-00-00", "@fidanzagameclub"),
    ("FIDANZA Game Club (Юнусабад)", "ул. Юнус-Ота, Юнусабад-14, 61А", 41.370300, 69.292100, 145, 4.4, "vip", True, False, "Филиал FIDANZA в Юнусабаде.", 18000, 25, "+998 95-144-24-42", "@fidanzagameclub"),
    ("Bezone Gaming (Буюк Ипак Йули)", "Массив Буюк Ипак Йули, 1", 41.313293, 69.287088, 60, 4.6, "standard", False, False, "Клуб площадью 1200 м2.", 15000, 44, "+998 95-515-05-00", "@bezone_gaming"),
    ("Bezone Gaming (Алпомиш)", "проспект Беруни, 41а, Ледовый дворец", 41.329400, 69.219500, 50, 4.4, "standard", False, False, "Филиал Bezone.", 15000, 20, "+998 95-515-05-00", "@bezone_gaming"),
    ("Depo Gaming (Яшнабад)", "Бирлашган 6-й проезд, 19", 41.287838, 69.348910, 60, 4.5, "standard", False, False, "60 мощных ПК.", 14000, 32, "+998 90-330-11-15", "@depo_game"),
    ("Depo Gaming (Чиланзар)", "Чиланзар 3-й квартал, 63а", 41.282819, 69.222305, 50, 5.0, "standard", False, False, "Филиал Depo Gaming.", 14000, 20, "+998 77-310-11-15", "@depo_game"),
    ("Bushido Gaming (Университетская)", "ул. Университетская, 5а/2", 41.350593, 69.207373, 60, 3.5, "standard", False, False, "Кибер-арена.", 15000, 6, "+998 50-102-01-01", "@bushido_gaming"),
    ("Bushido Gaming (Турккургон)", "Турккургон 6-й проезд, 29/1", 41.340709, 69.268601, 60, 3.6, "standard", False, False, "Кибер-арена в центре.", 15000, 17, "+998 95-774-00-40", "@bushido_malika"),
    ("MAJOR Premium Gaming", "жм Кораташ, 32а", 41.316012, 69.233524, 50, 3.5, "vip", True, False, "ПК, PlayStation, бар.", 17000, 14, "+998 78-888-15-55", "@majorclubuz"),
    ("Space Gaming", "ул. Амира Темура, 15", 41.305831, 69.279864, 40, 4.5, "standard", False, False, "У метро Амир Темур.", 16000, 30, "+998 88-088-00-88", "@spacegaming_uz"),
    ("Cyber Arena", "Махатмы Ганди, 14", 41.313513, 69.293673, 40, 4.3, "standard", False, False, "Рядом с метро Алимджан.", 14000, 42, "+998 99-857-00-37", "@cyberarena_uz"),
    ("Patronum", "Оккургон, 20Б", 41.323141, 69.303035, 35, 4.7, "standard", False, False, "Уютный клуб.", 14000, 42, "+998 90-929-66-67", None),
    ("xcore.uz", "ул. Юнусота, 6Б", 41.374514, 69.305394, 25, 2.3, "basic", False, False, "Компьютерный клуб.", 12000, 3, "+998 88-887-77-00", None),
    ("GG eSports", "ул. Урикзор, 141", 41.290200, 69.275300, 40, 4.2, "standard", False, False, "E-sports клуб.", 15000, 20, "+998 93-917-79-79", None),
    ("Underground", "ул. Тараса Шевченко, 8", 41.300300, 69.265200, 30, 4.0, "standard", False, False, "Клуб в центре.", 14000, 5, "+998 93-201-03-33", None),
    ("Warpoint VR (Минор)", "1-й Бадамзар Йули, 72", 41.355300, 69.278100, 10, 4.5, "vip", False, True, "Арена виртуальной реальности.", 25000, 10, "+998 90-188-87-66", None),
    ("Warpoint VR (Ойбек)", "ул. Афрасиаб, 12Б", 41.306400, 69.270300, 10, 5.0, "vip", False, True, "VR-игры и командные бои.", 25000, 16, "+998 90-947-78-78", None),
    ("WinZone", "ул. Богишамол, 14", 41.357100, 69.282200, 30, 4.0, "basic", False, False, "Компьютерный клуб.", 13000, 5, "+998 95-919-67-77", None),
    ("XXxGaming", "ул. Гейдар Алиев, 204", 41.305100, 69.265300, 25, 3.8, "basic", False, False, "Компьютерный клуб.", 12000, 3, "+998 95-500-00-77", None),
    ("Аркада", "ул. Кушбеги, 30Б", 41.290100, 69.270400, 30, 4.0, "basic", False, False, "Компьютерный клуб.", 12000, 5, "+998 71-230-01-99", None),
    ("Game Bit 24", "Чиланзар-2, 76", 41.280200, 69.210500, 25, 3.8, "basic", True, False, "Игровой клуб и караоке.", 11000, 5, "+998 71-277-75-57", None),
    ("Prime Time PlayStation", "ул. Мирабад, 27/9", 41.303200, 69.264100, 15, 4.0, "standard", True, False, "PlayStation клуб.", 20000, 5, "+998 71-252-24-01", None),
]

batch_size = 5
total = len(missing)
ok = 0

for i in range(0, total, batch_size):
    batch = missing[i:i+batch_size]
    values_parts = []
    for c in batch:
        name, address, lat, lon, pc, rating, tier, has_ps, has_vr, desc, price, reviews, phone, tg = c
        ne = name.replace("'", "''")
        ae = address.replace("'", "''")
        de = desc.replace("'", "''")
        ps = f"'{phone}'" if phone else "NULL"
        ts = f"'{tg}'" if tg else "NULL"
        val = f"(gen_random_uuid(),'{ne}','{ae}',{lat},{lon},'{{}}','{WH24}'::jsonb,{pc},{rating},'{{}}'::jsonb,'active','{tier}',now(),{'true' if has_ps else 'false'},{'true' if has_vr else 'false'},0,{pc},{lat},{lon},'{de}',{price},{reviews},{ps},{ts})"
        values_parts.append(val)
    sql = f"INSERT INTO public.clubs (id,name,address,lat,lon,photos,working_hours,pc_count,rating,payout_details,status,tier,created_at,has_playstation,has_vr,current_occupancy,total_capacity,latitude,longitude,description,price_per_hour,review_count,contact_phone,contact_telegram) VALUES {','.join(values_parts)};"
    result = run_sql(sql)
    if "error" in result.lower() or '"message"' in result:
        print(f"Batch {i//batch_size+1}: ERROR - {result[:150]}")
    else:
        ok += len(batch)
        print(f"Batch {i//batch_size+1}: OK ({ok} inserted)")

print(f"\n=== Final count ===")
print(run_sql("SELECT count(*) as total FROM public.clubs;"))
