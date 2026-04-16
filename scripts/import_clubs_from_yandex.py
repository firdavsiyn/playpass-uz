#!/usr/bin/env python3
"""
Import computer clubs from Yandex Maps (Tashkent) into Supabase.
Uses Yandex Geosuggest API (public, no key required) to find all orgs,
then fetches details via the Yandex Maps showcase API for each org.
"""
import re
import json
import time
import sys
import subprocess
import urllib.request
import urllib.parse
from difflib import SequenceMatcher

SUPABASE_MGMT = 'https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query'
SUPABASE_MGMT_TOKEN = 'sbp_856e4068bebec50c18b41dac00fd30695444208b'

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
HEADERS = {'User-Agent': UA, 'Accept': 'application/json', 'Accept-Language': 'ru-RU,ru;q=0.9'}

# Tashkent bbox (ll=center, spn=half-width,half-height)
TASHKENT_LL = '69.279737,41.311081'
TASHKENT_SPN = '0.5,0.5'  # covers whole city


def http_get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    return urllib.request.urlopen(req, timeout=20).read().decode('utf-8')


def sb_query(sql):
    """Execute SQL via Supabase Management API."""
    result = subprocess.run(
        ['curl', '-s', '-X', 'POST', SUPABASE_MGMT,
         '-H', f'Authorization: Bearer {SUPABASE_MGMT_TOKEN}',
         '-H', 'Content-Type: application/json',
         '-d', json.dumps({'query': sql})],
        capture_output=True, text=True, timeout=60
    )
    if result.returncode != 0:
        raise RuntimeError(f'curl failed: {result.stderr}')
    resp = result.stdout.strip()
    if not resp:
        return []
    parsed = json.loads(resp)
    if isinstance(parsed, dict) and 'error' in parsed:
        raise RuntimeError(f'SQL error: {parsed}')
    return parsed


def suggest_businesses(query):
    """Query Yandex Geosuggest for business matches."""
    url = (
        f'https://suggest-maps.yandex.ru/suggest-geo?v=9&lang=ru_RU&search_type=all'
        f'&origin=maps-tab-mobile&spn={TASHKENT_SPN}&ll={TASHKENT_LL}'
        f'&part={urllib.parse.quote(query)}&results=40'
    )
    try:
        resp = http_get(url)
    except Exception as e:
        print(f'  suggest error for "{query}": {e}', flush=True)
        return []

    # Response is JSONP: suggest.apply({...})
    match = re.search(r'suggest\.apply\((\{.+\})\)', resp, re.DOTALL)
    if not match:
        return []
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError:
        return []

    orgs = []
    for r in data.get('results', []):
        if r.get('type') == 'business':
            log = r.get('log_id', {})
            what = log.get('what', {})
            org_id = what.get('id')
            # Extract name from search_query JSON
            sq = r.get('search_query', '{}')
            try:
                sq_data = json.loads(sq) if isinstance(sq, str) else sq
                name = sq_data.get('text', '')
            except:
                name = ''
            if org_id and name:
                orgs.append({'id': org_id, 'name': name})
    return orgs


def fetch_business_details(org_id, org_name):
    """Fetch details for a business via Yandex showcase API."""
    url = (
        f'https://yandex.uz/maps/api/showcase?'
        f'bbox=69.0~41.1~69.6~41.5&csrfToken='
        f'&rubric=computer_center&lang=ru&ids={org_id}'
    )
    try:
        resp = http_get(url)
        data = json.loads(resp) if resp else None
    except Exception:
        data = None

    # Alternative: direct org page
    details = {'name': org_name}

    # Try org overview endpoint that returns JSON for organization cards
    try:
        # Yandex Search API via static organization landing
        org_url = f'https://yandex.uz/maps/org/{org_id}/'
        html = http_get(org_url)

        # Extract coords from meta
        coord_m = re.search(r'"coordinates":\[([0-9.]+),([0-9.]+)\]', html)
        if coord_m:
            details['lon'] = float(coord_m.group(1))
            details['lat'] = float(coord_m.group(2))

        # Address
        addr_m = re.search(r'"address":"([^"]+)"', html)
        if addr_m:
            details['address'] = addr_m.group(1).replace('\\u002F', '/')

        # Phone
        phone_m = re.search(r'"phone":"([^"]+)"', html)
        if phone_m:
            details['phone'] = phone_m.group(1)
    except Exception:
        pass

    return details


def normalize_name(name):
    n = name.lower().strip()
    n = re.sub(r'\s*\(.*?\)\s*', '', n)
    n = re.sub(r'[^\w\s]', '', n)
    n = re.sub(r'\s+', ' ', n)
    return n.strip()


def is_duplicate(new_name, new_lat, new_lon, existing_clubs):
    new_norm = normalize_name(new_name)
    for c in existing_clubs:
        existing_norm = normalize_name(c['name'])
        if new_norm == existing_norm:
            return True
        ratio = SequenceMatcher(None, new_norm, existing_norm).ratio()
        if ratio > 0.92:
            return True
        if new_lat and new_lon and c.get('lat') and c.get('lon'):
            if abs(float(c['lat']) - new_lat) < 0.0005 and abs(float(c['lon']) - new_lon) < 0.0005:
                return True
    return False


def escape_sql(s):
    if s is None or s == '':
        return 'NULL'
    return "'" + str(s).replace("'", "''") + "'"


def insert_clubs(clubs):
    if not clubs:
        return 0
    values = []
    for c in clubs:
        name = escape_sql(c['name'])
        address = escape_sql(c.get('address', 'Ташкент'))
        lat = c.get('lat') or 'NULL'
        lon = c.get('lon') or 'NULL'
        phone = escape_sql(c.get('phone'))
        values.append(
            f"({name}, {address}, {lat}, {lon}, "
            f"'{{}}'::text[], '{{}}'::jsonb, 20, 0.0, "
            f"'{{}}'::jsonb, 'active', 'basic', {phone})"
        )

    sql = f"""
    INSERT INTO clubs (name, address, lat, lon, photos, working_hours, pc_count, rating,
                       payout_details, status, tier, contact_phone)
    VALUES {','.join(values)}
    RETURNING id
    """
    try:
        result = sb_query(sql)
        return len(result) if isinstance(result, list) else 0
    except Exception as e:
        print(f'  Insert error: {e}', flush=True)
        return 0


def main():
    print('Yandex Maps → Supabase import (Tashkent computer clubs)\n', flush=True)

    # 1. Existing clubs
    existing = sb_query("SELECT name, lat, lon FROM clubs")
    print(f'Existing clubs in DB: {len(existing)}', flush=True)

    # 2. Search with many query variations to maximize coverage
    queries = [
        'компьютерные клубы',
        'компьютерный клуб',
        'геймерский клуб',
        'игровой клуб',
        'киберклуб',
        'game club',
        'gaming club',
        'PC club',
        'esports club',
        'cyber arena',
        'PlayStation клуб',
        'PS клуб',
        'VR клуб',
        'кибер арена',
        'геймпад',
        'playground',
        'gaming zone',
        'game zone',
        'game center',
        'internet cafe Ташкент',
        'интернет кафе',
    ]

    all_orgs = {}  # id → name
    print('\nSearching with query variations...', flush=True)
    for q in queries:
        results = suggest_businesses(q)
        new_count = 0
        for r in results:
            if r['id'] not in all_orgs:
                all_orgs[r['id']] = r['name']
                new_count += 1
        print(f'  "{q}": {len(results)} results ({new_count} new), total: {len(all_orgs)}', flush=True)
        time.sleep(0.3)

    print(f'\nTotal unique orgs from Yandex: {len(all_orgs)}', flush=True)

    # 3. Fetch details
    print('\nFetching details for each org...', flush=True)
    candidates = []
    for i, (org_id, name) in enumerate(all_orgs.items()):
        if (i + 1) % 20 == 0:
            print(f'  Processed {i+1}/{len(all_orgs)}...', flush=True)
        details = fetch_business_details(org_id, name)
        candidates.append(details)
        time.sleep(0.15)

    # Print sample of details
    with_coords = sum(1 for c in candidates if c.get('lat'))
    print(f'\n  With coordinates: {with_coords}/{len(candidates)}', flush=True)

    # 4. Dedup
    print('\nDeduplicating...', flush=True)
    to_insert = []
    skipped = 0
    seen = set()
    for c in candidates:
        key = normalize_name(c['name'])
        if key in seen:
            skipped += 1
            continue
        seen.add(key)
        if is_duplicate(c['name'], c.get('lat'), c.get('lon'), existing):
            skipped += 1
        else:
            to_insert.append(c)

    print(f'  New: {len(to_insert)}, skipped: {skipped}', flush=True)

    # 5. Insert
    print('\nInserting...', flush=True)
    total = 0
    for i in range(0, len(to_insert), 30):
        batch = to_insert[i:i+30]
        n = insert_clubs(batch)
        total += n
        print(f'  Batch {i//30 + 1}: {n}/{len(batch)}', flush=True)
        time.sleep(0.5)

    print(f'\n✅ Done! Inserted {total}, DB total: {len(existing) + total}', flush=True)


if __name__ == '__main__':
    main()
