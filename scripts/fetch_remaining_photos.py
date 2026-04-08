#!/usr/bin/env python3
"""
Targeted photo fetch for clubs not found by first script.
Uses alternative search terms and broader 2GIS matching.
"""
import requests, re, time, sys, os
from urllib.parse import quote

os.environ['PYTHONUNBUFFERED'] = '1'

SUPABASE_URL = 'https://rizyqzjszaknzjboooow.supabase.co'
SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs'
SUPABASE_MGMT = 'https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query'
SUPABASE_MGMT_TOKEN = 'sbp_856e4068bebec50c18b41dac00fd30695444208b'
BUCKET = 'club-photos'
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

session = requests.Session()
session.headers.update({'User-Agent': UA, 'Accept-Language': 'ru-RU,ru;q=0.9'})

# Alternative search terms for clubs not found by exact name
ALT_SEARCH = {
    'FIDANZA Game Club (Кадышева)': ['Fidanza Кадыри', 'Fidanza игровой клуб'],
    'FIDANZA Game Club (Себзар)': ['Fidanza Себзар', 'Fidanza игровой'],
    'FIDANZA Game Club (Юнусабад)': ['Fidanza Юнусабад', 'Fidanza game'],
    'Invictus Gaming Club': ['Invictus', 'Invictus gaming'],
    '025 Game Club': ['025 game', '025 гейм клуб'],
    '5x5 Game Club': ['5x5 game', '5x5 гейм'],
    'Bushido Gaming (Университетская)': ['Bushido Gaming Университетская', 'Bushido кибер-арена'],
    'Cougar Gaming Area': ['Cougar gaming', 'Cougar компьютерный'],
    'Cyber Arena Light': ['Cyber Arena Light', 'Кибер Арена Лайт'],
    'Darkside Game Club': ['Darkside game', 'Darkside компьютерный'],
    'Don Game Club': ['Don game club', 'Don гейм'],
    'E-Bash': ['E-Bash компьютерный', 'ибаш гейм'],
    'Epicenter E-Sports': ['Epicenter esports', 'Эпицентр киберспорт'],
    'Fenix Game Club': ['Fenix game', 'Феникс гейм клуб'],
    'Forbes Game Club': ['Forbes game', 'Форбс гейм'],
    'FoxGaming': ['Fox Gaming', 'Фокс гейминг'],
    'Game Bit 24': ['Game Bit', 'ГеймБит'],
    'Legacy Gaming Club': ['Legacy gaming', 'Легаси гейминг'],
    'Mirage Gaming': ['Mirage gaming', 'Мираж гейминг'],
    'Monkey Game Club': ['Monkey game', 'Манки гейм'],
    'Pantera Game Zone': ['Pantera game', 'Пантера гейм зон'],
    'Rio PlayStation Club': ['Rio PlayStation', 'Рио плейстейшн'],
    'ROG Game Club': ['ROG game', 'РОГ гейм клуб'],
    'XXxGaming': ['XXX gaming', 'Triple X gaming'],
}

stats = {'found': 0, 'not_found': 0, 'photos_uploaded': 0}


def get_clubs_without_photos():
    r = requests.get(
        f'{SUPABASE_URL}/rest/v1/clubs?select=id,name,address&photos=eq.{{}}',
        headers={'apikey': SUPABASE_ANON, 'Authorization': f'Bearer {SUPABASE_ANON}'},
        timeout=10
    )
    r.raise_for_status()
    return r.json()


def search_2gis(query):
    url = f'https://2gis.uz/tashkent/search/{quote(query)}'
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return []
        return list(dict.fromkeys(re.findall(r'firm/(\d+)', r.text)))
    except:
        return []


def get_firm_photos(firm_id):
    """Get photos from a 2GIS firm page + try direct URL."""
    photos = []

    # Try direct main photo URL
    try:
        r = session.head(f'https://i4.photo.2gis.com/main/branch/208/{firm_id}/common', timeout=10)
        if r.status_code == 200:
            photos.append(f'https://i4.photo.2gis.com/main/branch/208/{firm_id}/common')
    except:
        pass

    # Fetch firm page for additional photos
    try:
        r = session.get(f'https://2gis.uz/tashkent/firm/{firm_id}', timeout=15)
        if r.status_code == 200:
            html = r.text
            for p in re.findall(r'https://i\d+\.photo\.2gis\.com/main/(?:branch|geo)/\d+/\d+/\w+', html):
                if p not in photos:
                    photos.append(p)
            for p in re.findall(r'https://i\d+\.photo\.2gis\.com/images/[^\"\s\\]+_(?:1920x|640x)\.jpg', html):
                if p not in photos:
                    photos.append(p)
    except:
        pass

    return photos[:3]


def download_photo(url):
    try:
        r = session.get(url, timeout=20)
        if r.status_code == 200 and len(r.content) > 5000:
            return r.content
    except:
        pass
    return None


def upload_to_supabase(club_id, photo_bytes, index):
    path = f'{club_id}/photo_{index}.jpg'
    r = requests.post(
        f'{SUPABASE_URL}/storage/v1/object/{BUCKET}/{path}',
        headers={'Authorization': f'Bearer {SUPABASE_ANON}', 'apikey': SUPABASE_ANON,
                 'Content-Type': 'image/jpeg', 'x-upsert': 'true'},
        data=photo_bytes, timeout=30)
    if r.status_code in (200, 201):
        return f'{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}'
    return None


def update_club_photos(club_id, photo_urls):
    photos_pg = '{' + ','.join(f'"{u}"' for u in photo_urls) + '}'
    sql = f"UPDATE public.clubs SET photos = '{photos_pg}' WHERE id = '{club_id}';"
    try:
        r = requests.post(SUPABASE_MGMT,
            headers={'Authorization': f'Bearer {SUPABASE_MGMT_TOKEN}', 'Content-Type': 'application/json'},
            json={'query': sql}, timeout=10)
        return r.status_code in (200, 201)
    except:
        return False


def process_club(club, index, total):
    name = club['name']
    club_id = club['id']
    print(f'\n[{index}/{total}] {name}')
    sys.stdout.flush()

    # Build list of search queries to try
    queries = [name]
    # Remove parenthetical
    short = re.sub(r'\s*\(.*?\)\s*', '', name).strip()
    if short != name:
        queries.append(short)
    # Alternative search terms
    if name in ALT_SEARCH:
        queries.extend(ALT_SEARCH[name])

    # Try each query on 2GIS
    found_photos = []
    for q in queries:
        print(f'  🔍 2GIS: "{q}"')
        firm_ids = search_2gis(q)
        if firm_ids:
            # Try each firm for photos
            for fid in firm_ids[:3]:
                photos = get_firm_photos(fid)
                if photos:
                    found_photos = photos
                    print(f'  ✅ Found {len(photos)} photo(s) [firm={fid}]')
                    break
                time.sleep(0.3)
        if found_photos:
            break
        time.sleep(0.5)

    if not found_photos:
        print(f'  ❌ Still not found')
        stats['not_found'] += 1
        return

    # Download and upload
    uploaded = []
    for i, url in enumerate(found_photos):
        data = download_photo(url)
        if data:
            pub_url = upload_to_supabase(club_id, data, i)
            if pub_url:
                uploaded.append(pub_url)
                stats['photos_uploaded'] += 1
                print(f'  📷 Uploaded photo {i+1} ({len(data)//1024}KB)')
        time.sleep(0.3)

    if uploaded:
        if update_club_photos(club_id, uploaded):
            print(f'  💾 DB updated with {len(uploaded)} photos')
            stats['found'] += 1
        else:
            print(f'  [ERR] DB update failed')
    else:
        stats['not_found'] += 1


def main():
    print('🎯 PlayPass — Targeted Photo Fetch (Round 2)')
    print('=' * 50)
    clubs = get_clubs_without_photos()
    print(f'Found {len(clubs)} clubs still without photos\n')
    if not clubs:
        print('All clubs have photos!')
        return
    for i, club in enumerate(clubs, 1):
        try:
            process_club(club, i, len(clubs))
        except Exception as e:
            print(f'  [ERR] {e}')
        time.sleep(0.3)
    print(f'\n{"="*50}')
    print(f'📊 Results:')
    print(f'  ✅ Found: {stats["found"]}')
    print(f'  ❌ Still missing: {stats["not_found"]}')
    print(f'  📷 Uploaded: {stats["photos_uploaded"]} photos')


if __name__ == '__main__':
    main()
