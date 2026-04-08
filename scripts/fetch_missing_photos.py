#!/usr/bin/env python3
"""
Fetch photos for clubs NOT found on 2GIS — using Yandex Maps and Google.
"""
import requests
import re
import json
import time
import sys
import os
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

stats = {'found': 0, 'not_found': 0, 'photos_uploaded': 0}


def get_clubs_without_photos():
    """Get clubs that have empty photos array."""
    r = requests.get(
        f'{SUPABASE_URL}/rest/v1/clubs?select=id,name,address&photos=eq.{{}}',
        headers={'apikey': SUPABASE_ANON, 'Authorization': f'Bearer {SUPABASE_ANON}'},
        timeout=10
    )
    r.raise_for_status()
    return r.json()


def search_yandex_maps(query):
    """Search Yandex Maps and extract photo URLs."""
    url = f'https://yandex.uz/maps/10335/tashkent/search/{quote(query)}'
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return []
        html = r.text

        # Extract Yandex CDN photo URLs (avatars.mds.yandex.net)
        raw_urls = re.findall(
            r'https://avatars\.mds\.yandex\.net/get-altay/[^\"\s]+?/%s',
            html
        )
        # Deduplicate while preserving order
        seen = set()
        unique = []
        for u in raw_urls:
            base = u.replace('/%s', '')
            if base not in seen:
                seen.add(base)
                unique.append(base + '/XXXL')  # High-res version
        return unique[:5]  # Return up to 5 candidates
    except Exception as e:
        print(f'  [WARN] Yandex search error: {e}')
        return []


def search_yandex_org(query):
    """Try to find a specific org page on Yandex and get its photos."""
    url = f'https://yandex.uz/maps/10335/tashkent/search/{quote(query)}'
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return []
        html = r.text

        # Find org page links
        org_ids = re.findall(r'/org/[^/]+/(\d+)', html)
        if not org_ids:
            return []

        # Fetch org page for photos
        org_id = org_ids[0]
        org_url = f'https://yandex.uz/maps/org/{org_id}/'
        r2 = session.get(org_url, timeout=15)
        if r2.status_code != 200:
            return []

        # Extract photos from org page
        raw_urls = re.findall(
            r'https://avatars\.mds\.yandex\.net/get-altay/[^\"\s]+?/%s',
            r2.text
        )
        seen = set()
        unique = []
        for u in raw_urls:
            base = u.replace('/%s', '')
            if base not in seen:
                seen.add(base)
                unique.append(base + '/XXXL')
        return unique[:5]
    except Exception as e:
        print(f'  [WARN] Yandex org error: {e}')
        return []


def search_google_images(query):
    """Search Google for images of the club."""
    search_query = f'{query} компьютерный клуб Ташкент'
    url = f'https://www.google.com/search?q={quote(search_query)}&tbm=isch'
    try:
        r = session.get(url, timeout=15, headers={
            'User-Agent': UA,
            'Accept': 'text/html',
        })
        if r.status_code != 200:
            return []

        # Extract image URLs from Google Images
        # Google embeds base64 thumbnails but also has links to original images
        img_urls = re.findall(
            r'https://(?:lh\d+\.googleusercontent\.com|encrypted-tbn\d+\.gstatic\.com)/[^\"\s&]+',
            r.text
        )
        # Filter for reasonable quality (googleusercontent)
        good_urls = [u for u in img_urls if 'googleusercontent.com' in u]
        if not good_urls:
            good_urls = img_urls[:3]
        return list(dict.fromkeys(good_urls))[:3]
    except Exception as e:
        print(f'  [WARN] Google search error: {e}')
        return []


def download_photo(url):
    """Download a photo and return bytes."""
    try:
        r = session.get(url, timeout=20)
        if r.status_code == 200 and len(r.content) > 5000:
            return r.content
    except Exception as e:
        print(f'  [WARN] Download error: {e}')
    return None


def upload_to_supabase(club_id, photo_bytes, index):
    """Upload photo to Supabase Storage."""
    path = f'{club_id}/photo_{index}.jpg'
    upload_url = f'{SUPABASE_URL}/storage/v1/object/{BUCKET}/{path}'
    r = requests.post(
        upload_url,
        headers={
            'Authorization': f'Bearer {SUPABASE_ANON}',
            'apikey': SUPABASE_ANON,
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',
        },
        data=photo_bytes,
        timeout=30,
    )
    if r.status_code in (200, 201):
        return f'{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}'
    else:
        print(f'  [ERR] Upload failed ({r.status_code})')
        return None


def update_club_photos(club_id, photo_urls):
    """Update DB via Management API."""
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
    address = club.get('address', '')
    print(f'\n[{index}/{total}] {name}')
    sys.stdout.flush()

    photo_urls = []

    # Strategy 1: Yandex Maps search by name
    print(f'  🔍 Yandex Maps: "{name}"')
    photo_urls = search_yandex_maps(name)

    # Strategy 2: Yandex org page
    if not photo_urls:
        print(f'  🔍 Yandex Org: "{name}"')
        photo_urls = search_yandex_org(name)
        time.sleep(0.5)

    # Strategy 3: Try name without parentheses
    if not photo_urls:
        short = re.sub(r'\s*\(.*?\)\s*', '', name).strip()
        if short != name:
            print(f'  🔍 Yandex Maps: "{short}"')
            photo_urls = search_yandex_maps(short)
            time.sleep(0.5)

    # Strategy 4: Name + "Ташкент" on Yandex
    if not photo_urls:
        q = f'{name} Ташкент'
        print(f'  🔍 Yandex Maps: "{q}"')
        photo_urls = search_yandex_maps(q)
        time.sleep(0.5)

    # Strategy 5: Google Images
    if not photo_urls:
        print(f'  🔍 Google Images...')
        photo_urls = search_google_images(name)
        time.sleep(0.5)

    if not photo_urls:
        print(f'  ❌ Not found anywhere')
        stats['not_found'] += 1
        return

    # Download and upload up to 3 photos
    print(f'  Found {len(photo_urls)} candidate(s)')
    uploaded = []
    for i, url in enumerate(photo_urls[:3]):
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
        print(f'  ❌ Download failed for all candidates')
        stats['not_found'] += 1


def main():
    print('🔎 PlayPass — Missing Photos Fetcher (Yandex + Google)')
    print('=' * 55)

    clubs = get_clubs_without_photos()
    total = len(clubs)
    print(f'Found {total} clubs without photos\n')

    if total == 0:
        print('All clubs already have photos!')
        return

    for i, club in enumerate(clubs, 1):
        try:
            process_club(club, i, total)
        except Exception as e:
            print(f'  [ERR] {e}')
        time.sleep(0.5)

    print('\n' + '=' * 55)
    print(f'📊 Results:')
    print(f'  ✅ Found: {stats["found"]} clubs')
    print(f'  ❌ Still missing: {stats["not_found"]} clubs')
    print(f'  📷 Uploaded: {stats["photos_uploaded"]} photos')


if __name__ == '__main__':
    main()
