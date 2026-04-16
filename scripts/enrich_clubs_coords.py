#!/usr/bin/env python3
"""
Enrich clubs that lack coordinates by searching them on 2GIS.
2GIS has reliable server-rendered data with coordinates for Tashkent businesses.
"""
import re
import json
import time
import subprocess
import urllib.request
import urllib.parse

SUPABASE_MGMT = 'https://api.supabase.com/v1/projects/rizyqzjszaknzjboooow/database/query'
SUPABASE_MGMT_TOKEN = 'sbp_856e4068bebec50c18b41dac00fd30695444208b'
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'


def http_get(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    return urllib.request.urlopen(req, timeout=20).read().decode('utf-8')


def sb_query(sql):
    result = subprocess.run(
        ['curl', '-s', '-X', 'POST', SUPABASE_MGMT,
         '-H', f'Authorization: Bearer {SUPABASE_MGMT_TOKEN}',
         '-H', 'Content-Type: application/json',
         '-d', json.dumps({'query': sql})],
        capture_output=True, text=True, timeout=60
    )
    resp = result.stdout.strip()
    if not resp:
        return []
    parsed = json.loads(resp)
    if isinstance(parsed, dict) and 'error' in parsed:
        raise RuntimeError(f'SQL error: {parsed}')
    return parsed


def search_2gis(name):
    """Search 2GIS for a club by name; return details or None."""
    search_url = f'https://2gis.uz/tashkent/search/{urllib.parse.quote(name)}'
    try:
        html = http_get(search_url)
    except Exception:
        return None

    m = re.search(r'/tashkent/firm/(\d+)', html)
    if not m:
        return None
    firm_id = m.group(1)

    try:
        firm_html = http_get(f'https://2gis.uz/tashkent/firm/{firm_id}')
    except Exception:
        return None

    # Extract first Tashkent-area coord (firm location, not city center)
    coord = None
    for cm in re.finditer(r'"lat":([0-9.]+),"lon":([0-9.]+)', firm_html):
        lat, lon = float(cm.group(1)), float(cm.group(2))
        if 41.0 < lat < 41.5 and 68.9 < lon < 69.6:
            # Skip city center default (41.311, 69.279)
            if abs(lat - 41.311) > 0.002 or abs(lon - 69.279) > 0.002:
                coord = (lat, lon)
                break

    addr_m = re.search(r'"address_name":"([^"]+)"', firm_html)
    address = addr_m.group(1) if addr_m else None

    title_m = re.search(r'<title>([^<]+)</title>', firm_html)
    actual_name = None
    if title_m:
        actual_name = title_m.group(1).split(',')[0].strip()

    ph_m = re.search(r'tel:(\+?\d[\d\s\-\(\)]{7,})', firm_html)
    phone = ph_m.group(1).strip() if ph_m else None

    return {
        'name': actual_name,
        'address': address,
        'lat': coord[0] if coord else None,
        'lon': coord[1] if coord else None,
        'phone': phone,
    }


def escape_sql(s):
    if s is None or s == '':
        return 'NULL'
    return "'" + str(s).replace("'", "''") + "'"


def main():
    print('Enriching clubs without coordinates via 2GIS search...\n', flush=True)

    clubs = sb_query(
        "SELECT id, name, lat, lon, address, contact_phone "
        "FROM clubs WHERE lat IS NULL OR address = 'Ташкент' "
        "ORDER BY name"
    )
    print(f'Clubs needing enrichment: {len(clubs)}\n', flush=True)

    updated = 0
    failed = 0
    for i, club in enumerate(clubs):
        if (i + 1) % 20 == 0:
            print(f'  Progress: {i+1}/{len(clubs)} (updated: {updated}, failed: {failed})', flush=True)

        details = search_2gis(club['name'])
        if not details or not details.get('lat'):
            failed += 1
            continue

        # Build update statement
        updates = []
        if details.get('lat') and (not club.get('lat') or club['lat'] is None):
            updates.append(f"lat={details['lat']}")
            updates.append(f"lon={details['lon']}")
        if details.get('address') and (not club.get('address') or club['address'] == 'Ташкент'):
            updates.append(f"address={escape_sql(details['address'])}")
        if details.get('phone') and not club.get('contact_phone'):
            updates.append(f"contact_phone={escape_sql(details['phone'])}")

        if not updates:
            failed += 1
            continue

        sql = f"UPDATE clubs SET {', '.join(updates)} WHERE id={escape_sql(club['id'])}"
        try:
            sb_query(sql)
            updated += 1
        except Exception as e:
            print(f'  Update failed for {club["name"]}: {e}', flush=True)
            failed += 1

        time.sleep(0.3)

    print(f'\n✅ Enrichment complete!', flush=True)
    print(f'   Updated: {updated}', flush=True)
    print(f'   Failed: {failed}', flush=True)

    stats = sb_query(
        "SELECT COUNT(*) total, COUNT(lat) with_coords, "
        "COUNT(CASE WHEN address != 'Ташкент' THEN 1 END) with_addr, "
        "COUNT(contact_phone) with_phone FROM clubs"
    )
    print(f'\nFinal DB stats: {stats[0]}', flush=True)


if __name__ == '__main__':
    main()
