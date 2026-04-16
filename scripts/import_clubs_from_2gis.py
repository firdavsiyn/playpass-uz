#!/usr/bin/env python3
"""
Import computer clubs from 2GIS (Tashkent) into Supabase.
Scrapes all pages of the search results, fetches details per firm,
deduplicates against existing clubs, and inserts new ones.
"""
import re
import time
import json
import sys
import urllib.request
import urllib.parse
from difflib import SequenceMatcher

SUPABASE_URL = 'https://rizyqzjszaknzjboooow.supabase.co'
SUPABASE_MGMT = 'https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query'
SUPABASE_MGMT_TOKEN = 'sbp_856e4068bebec50c18b41dac00fd30695444208b'

UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
HEADERS = {'User-Agent': UA, 'Accept': 'text/html,application/json', 'Accept-Language': 'ru-RU,ru;q=0.9'}

SEARCH_URL_TEMPLATE = 'https://2gis.uz/tashkent/search/%D0%BA%D0%BE%D0%BC%D0%BF%D1%8C%D1%8E%D1%82%D0%B5%D1%80%D0%BD%D1%8B%D0%B5%20%D0%BA%D0%BB%D1%83%D0%B1%D1%8B/page/{page}'


def http_get(url):
    req = urllib.request.Request(url, headers=HEADERS)
    return urllib.request.urlopen(req, timeout=20).read().decode('utf-8')


def fetch_page(page):
    """Fetch one page of search results. Returns list of (firm_id, name)."""
    url = SEARCH_URL_TEMPLATE.format(page=page)
    try:
        html = http_get(url)
    except Exception as e:
        print(f'  Page {page}: HTTP error {e}', flush=True)
        return []

    # Extract firm ID + name pairs
    pattern = r'href="/tashkent/firm/(\d+)"[^>]*><span[^>]*><span>([^<]+)</span>'
    results = []
    for m in re.finditer(pattern, html):
        firm_id, name = m.group(1), m.group(2).strip()
        if firm_id and name:
            results.append((firm_id, name))
    return results


def fetch_firm_details(firm_id):
    """Fetch full firm details: address, coords, phone, schedule."""
    url = f'https://2gis.uz/tashkent/firm/{firm_id}'
    try:
        html = http_get(url)
    except Exception as e:
        return None

    data = {}

    # Extract JSON-LD (structured data) if present
    jsonld_match = re.search(
        r'<script type="application/ld\+json">(\{.+?\})</script>',
        html, re.DOTALL
    )
    if jsonld_match:
        try:
            jld = json.loads(jsonld_match.group(1))
            data['name'] = jld.get('name', '')
            if 'address' in jld:
                addr = jld['address']
                if isinstance(addr, dict):
                    data['address'] = addr.get('streetAddress', '')
                else:
                    data['address'] = str(addr)
            if 'geo' in jld:
                data['lat'] = jld['geo'].get('latitude')
                data['lon'] = jld['geo'].get('longitude')
            if 'telephone' in jld:
                data['phone'] = jld['telephone']
        except:
            pass

    # Fallback: parse from HTML patterns
    if 'lat' not in data or not data.get('lat'):
        # Look for coordinates in meta tags or embedded state
        coord_match = re.search(r'"point":\s*\{\s*"lon":\s*([0-9.]+),\s*"lat":\s*([0-9.]+)', html)
        if coord_match:
            data['lon'] = float(coord_match.group(1))
            data['lat'] = float(coord_match.group(2))

    if 'address' not in data or not data.get('address'):
        addr_match = re.search(r'"address_name":\s*"([^"]+)"', html)
        if addr_match:
            data['address'] = addr_match.group(1)

    if 'phone' not in data:
        phone_match = re.search(r'tel:(\+?\d{7,})', html)
        if phone_match:
            data['phone'] = phone_match.group(1)

    return data if data.get('address') or data.get('lat') else None


def normalize_name(name):
    """Normalize name for dedup comparison."""
    n = name.lower().strip()
    # Remove common suffixes
    n = re.sub(r'\s*\(.*?\)\s*', '', n)
    n = re.sub(r'[^\w\s]', '', n)
    n = re.sub(r'\s+', ' ', n)
    return n


def is_duplicate(new_name, new_lat, new_lon, existing_clubs):
    """Check if club already exists."""
    new_norm = normalize_name(new_name)
    for c in existing_clubs:
        # Name match (fuzzy)
        existing_norm = normalize_name(c['name'])
        if new_norm == existing_norm:
            return True
        ratio = SequenceMatcher(None, new_norm, existing_norm).ratio()
        if ratio > 0.92:
            return True
        # Coord match (within ~50m)
        if new_lat and new_lon and c.get('lat') and c.get('lon'):
            if abs(float(c['lat']) - new_lat) < 0.0005 and abs(float(c['lon']) - new_lon) < 0.0005:
                return True
    return False


def sb_query(sql, params=None):
    """Run a SQL query via Supabase Management API using curl (reliable)."""
    import subprocess
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


def get_existing_clubs():
    return sb_query("SELECT name, lat, lon FROM clubs")


def escape_sql(s):
    if s is None:
        return 'NULL'
    return "'" + str(s).replace("'", "''") + "'"


def insert_clubs(clubs):
    """Batch insert clubs."""
    if not clubs:
        return 0

    values = []
    for c in clubs:
        name = escape_sql(c['name'])
        address = escape_sql(c.get('address', 'Tashkent'))
        lat = c.get('lat') or 'NULL'
        lon = c.get('lon') or 'NULL'
        phone = escape_sql(c.get('phone'))
        # Default values for required fields
        values.append(
            f"({name}, {address}, {lat}, {lon}, "
            f"'{{}}'::text[], '{{}}'::jsonb, 20, 0.0, "
            f"'{{}}'::jsonb, 'active', 'basic', {phone})"
        )

    sql = f"""
    INSERT INTO clubs (name, address, lat, lon, photos, working_hours, pc_count, rating,
                       payout_details, status, tier, contact_phone)
    VALUES {','.join(values)}
    RETURNING id, name
    """
    try:
        result = sb_query(sql)
        return len(result) if isinstance(result, list) else 0
    except Exception as e:
        print(f'  Insert error: {e}', flush=True)
        return 0


def main():
    print('Starting 2GIS → Supabase import...\n', flush=True)

    # 1. Get existing clubs
    existing = get_existing_clubs()
    print(f'Existing clubs in DB: {len(existing)}', flush=True)

    # 2. Scrape all pages from 2GIS
    print('\nScraping 2GIS search results...', flush=True)
    all_firms = {}  # firm_id -> name
    page = 1
    empty_pages = 0
    while True:
        results = fetch_page(page)
        if not results:
            empty_pages += 1
            if empty_pages >= 3:
                print(f'  Stopping after 3 empty pages.', flush=True)
                break
        else:
            empty_pages = 0
            new_count = 0
            for firm_id, name in results:
                if firm_id not in all_firms:
                    all_firms[firm_id] = name
                    new_count += 1
            print(f'  Page {page}: {len(results)} results ({new_count} new), total so far: {len(all_firms)}', flush=True)
        page += 1
        if page > 40:  # Safety cap (12/page × 40 = 480, covers 418)
            break
        time.sleep(0.5)

    print(f'\nTotal unique firms found on 2GIS: {len(all_firms)}', flush=True)

    # 3. Fetch details for each firm
    print('\nFetching firm details (this may take a few minutes)...', flush=True)
    candidates = []
    for i, (firm_id, name) in enumerate(all_firms.items()):
        if (i + 1) % 20 == 0:
            print(f'  Processed {i+1}/{len(all_firms)}...', flush=True)
        details = fetch_firm_details(firm_id)
        if details:
            details['name'] = details.get('name') or name
            candidates.append(details)
        else:
            # Still add with just name
            candidates.append({'name': name, 'address': 'Ташкент'})
        time.sleep(0.2)  # Rate limit

    print(f'\nCandidates with details: {len(candidates)}', flush=True)

    # 4. Deduplicate against existing DB
    print('\nDeduplicating against existing DB clubs...', flush=True)
    to_insert = []
    skipped = 0
    for c in candidates:
        lat = c.get('lat')
        lon = c.get('lon')
        if is_duplicate(c['name'], lat, lon, existing):
            skipped += 1
        else:
            to_insert.append(c)

    print(f'  New clubs to insert: {len(to_insert)}', flush=True)
    print(f'  Duplicates skipped: {skipped}', flush=True)

    # 5. Insert in batches of 50
    print('\nInserting new clubs into Supabase...', flush=True)
    inserted_total = 0
    batch_size = 30
    for i in range(0, len(to_insert), batch_size):
        batch = to_insert[i:i+batch_size]
        n = insert_clubs(batch)
        inserted_total += n
        print(f'  Batch {i//batch_size + 1}: inserted {n}/{len(batch)}', flush=True)
        time.sleep(0.5)

    print(f'\n✅ Import complete!', flush=True)
    print(f'   Total inserted: {inserted_total}', flush=True)
    print(f'   DB total now: {len(existing) + inserted_total}', flush=True)


if __name__ == '__main__':
    main()
