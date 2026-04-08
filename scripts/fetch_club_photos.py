#!/usr/bin/env python3
"""
Fetch real photos for gaming clubs from 2GIS and upload to Supabase Storage.
"""
import requests
import re
import json
import time
import sys
import os
from urllib.parse import quote

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True) if hasattr(sys.stdout, 'reconfigure') else None
os.environ['PYTHONUNBUFFERED'] = '1'

SUPABASE_URL = 'https://rizyqzjszaknzjboooow.supabase.co'
SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs'
SUPABASE_MGMT = 'https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query'
SUPABASE_MGMT_TOKEN = 'sbp_856e4068bebec50c18b41dac00fd30695444208b'
BUCKET = 'club-photos'
HEADERS_2GIS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'ru-RU,ru;q=0.9',
}

session = requests.Session()
session.headers.update(HEADERS_2GIS)

stats = {'found': 0, 'not_found': 0, 'photos_uploaded': 0, 'errors': 0}


def get_all_clubs():
    """Get all clubs from Supabase."""
    r = requests.get(
        f'{SUPABASE_URL}/rest/v1/clubs?select=id,name,address,photos&order=name',
        headers={'apikey': SUPABASE_ANON, 'Authorization': f'Bearer {SUPABASE_ANON}'}
    )
    r.raise_for_status()
    return r.json()


def search_2gis(club_name):
    """Search 2GIS for a club and return list of firm IDs."""
    url = f'https://2gis.uz/tashkent/search/{quote(club_name)}'
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return []
        firm_ids = re.findall(r'firm/(\d+)', r.text)
        return list(dict.fromkeys(firm_ids))  # unique, preserve order
    except Exception as e:
        print(f'  [WARN] Search error: {e}')
        return []


def get_firm_photos(firm_id):
    """Fetch a 2GIS firm page and extract photo URLs."""
    url = f'https://2gis.uz/tashkent/firm/{firm_id}'
    try:
        r = session.get(url, timeout=15)
        if r.status_code != 200:
            return []
        html = r.text
        photos = []

        # 1. Main branch photo
        branch_matches = re.findall(r'https://i\d+\.photo\.2gis\.com/main/branch/\d+/\d+/common', html)
        for m in branch_matches:
            if m not in photos:
                photos.append(m)

        # 2. Geo/building view
        geo_matches = re.findall(r'https://i\d+\.photo\.2gis\.com/main/geo/\d+/\d+/view', html)
        for m in geo_matches:
            if m not in photos:
                photos.append(m)

        # 3. Review/user photos (high-res)
        review_matches = re.findall(r'https://i\d+\.photo\.2gis\.com/images/[^\"\s\\]+_1920x\.jpg', html)
        for m in review_matches:
            if m not in photos:
                photos.append(m)

        # 4. If still < 3, try other user photos (640x)
        if len(photos) < 3:
            review_640 = re.findall(r'https://i\d+\.photo\.2gis\.com/images/[^\"\s\\]+_640x\.jpg', html)
            for m in review_640:
                if m not in photos:
                    photos.append(m)

        return photos[:3]
    except Exception as e:
        print(f'  [WARN] Firm page error: {e}')
        return []


def download_photo(url):
    """Download a photo and return bytes."""
    try:
        r = session.get(url, timeout=20)
        if r.status_code == 200 and len(r.content) > 5000:  # Minimum 5KB
            return r.content
    except Exception as e:
        print(f'  [WARN] Download error: {e}')
    return None


def upload_to_supabase(club_id, photo_bytes, index):
    """Upload photo to Supabase Storage and return public URL."""
    path = f'{club_id}/photo_{index}.jpg'
    upload_url = f'{SUPABASE_URL}/storage/v1/object/{BUCKET}/{path}'

    # Try to delete existing first (in case of re-run)
    requests.delete(
        upload_url,
        headers={'Authorization': f'Bearer {SUPABASE_ANON}', 'apikey': SUPABASE_ANON}
    )

    r = requests.post(
        upload_url,
        headers={
            'Authorization': f'Bearer {SUPABASE_ANON}',
            'apikey': SUPABASE_ANON,
            'Content-Type': 'image/jpeg',
            'x-upsert': 'true',
        },
        data=photo_bytes
    )
    if r.status_code in (200, 201):
        public_url = f'{SUPABASE_URL}/storage/v1/object/public/{BUCKET}/{path}'
        return public_url
    else:
        print(f'  [ERR] Upload failed ({r.status_code}): {r.text[:200]}')
        return None


def update_club_photos(club_id, photo_urls):
    """Update club photos in the database via Management API."""
    photos_pg = '{' + ','.join(f'"{u}"' for u in photo_urls) + '}'
    sql = f"UPDATE public.clubs SET photos = '{photos_pg}' WHERE id = '{club_id}';"
    try:
        r = requests.post(
            SUPABASE_MGMT,
            headers={
                'Authorization': f'Bearer {SUPABASE_MGMT_TOKEN}',
                'Content-Type': 'application/json',
            },
            json={'query': sql},
            timeout=10,
        )
        if r.status_code in (200, 201):
            return True
        print(f'  [ERR] DB update: {r.status_code} {r.text[:150]}')
        return False
    except Exception as e:
        print(f'  [ERR] DB update exception: {e}')
        return False


def check_existing_photos(club_id):
    """Check if club already has real photos in storage."""
    try:
        r = requests.post(
            f'{SUPABASE_URL}/storage/v1/object/list/{BUCKET}',
            headers={
                'apikey': SUPABASE_ANON,
                'Authorization': f'Bearer {SUPABASE_ANON}',
                'Content-Type': 'application/json',
            },
            json={'prefix': f'{club_id}/', 'limit': 5},
            timeout=10,
        )
        if r.status_code == 200:
            files = r.json()
            return [f for f in files if f.get('name', '').startswith('photo_')]
        return []
    except:
        return []


def process_club(club, index, total):
    """Process a single club: search, download photos, upload."""
    name = club['name']
    club_id = club['id']
    print(f'\n[{index}/{total}] {name}')

    sys.stdout.flush()

    # Search 2GIS
    firm_ids = search_2gis(name)
    if not firm_ids:
        # Try shorter name (first word or without parentheses)
        short_name = re.sub(r'\s*\(.*?\)\s*', '', name).strip()
        if short_name != name:
            print(f'  Retry with: {short_name}')
            firm_ids = search_2gis(short_name)
        if not firm_ids:
            # Try adding "компьютерный клуб"
            firm_ids = search_2gis(f'{name} компьютерный клуб')

    if not firm_ids:
        print(f'  ❌ Not found on 2GIS')
        # Set empty photos
        update_club_photos(club_id, [])
        stats['not_found'] += 1
        return

    # Try each firm until we find photos
    photos_urls = []
    for fid in firm_ids[:3]:  # Try top 3 matches
        photos_urls = get_firm_photos(fid)
        if photos_urls:
            print(f'  ✅ Found {len(photos_urls)} photo(s) [firm={fid}]')
            break
        time.sleep(0.3)

    if not photos_urls:
        # Even if firm was found, it may not have photos
        # Try the main photo URL pattern directly
        main_url = f'https://i4.photo.2gis.com/main/branch/208/{firm_ids[0]}/common'
        test = session.head(main_url, timeout=10)
        if test.status_code == 200:
            photos_urls = [main_url]
            print(f'  ✅ Found main photo via direct URL')
        else:
            print(f'  ❌ Firm found but no photos')
            update_club_photos(club_id, [])
            stats['not_found'] += 1
            return

    # Download and upload photos
    uploaded_urls = []
    for i, photo_url in enumerate(photos_urls):
        photo_data = download_photo(photo_url)
        if photo_data:
            public_url = upload_to_supabase(club_id, photo_data, i)
            if public_url:
                uploaded_urls.append(public_url)
                stats['photos_uploaded'] += 1
                print(f'  📷 Uploaded photo {i+1} ({len(photo_data)//1024}KB)')
        time.sleep(0.2)

    if uploaded_urls:
        if update_club_photos(club_id, uploaded_urls):
            print(f'  💾 DB updated with {len(uploaded_urls)} photos')
            stats['found'] += 1
        else:
            print(f'  [ERR] DB update failed')
            stats['errors'] += 1
    else:
        print(f'  ❌ No photos downloaded successfully')
        update_club_photos(club_id, [])
        stats['not_found'] += 1


def main():
    print('🎮 PlayPass Club Photo Fetcher')
    print('=' * 50)

    clubs = get_all_clubs()
    total = len(clubs)
    print(f'Found {total} clubs in database\n')

    for i, club in enumerate(clubs, 1):
        try:
            process_club(club, i, total)
        except Exception as e:
            print(f'  [ERR] Unexpected error: {e}')
            stats['errors'] += 1
        time.sleep(0.5)  # Rate limiting

    print('\n' + '=' * 50)
    print(f'📊 Results:')
    print(f'  ✅ Found photos: {stats["found"]} clubs')
    print(f'  ❌ No photos: {stats["not_found"]} clubs')
    print(f'  📷 Total uploaded: {stats["photos_uploaded"]} photos')
    print(f'  ⚠️  Errors: {stats["errors"]}')


if __name__ == '__main__':
    main()
