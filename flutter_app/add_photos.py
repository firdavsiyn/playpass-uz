#!/usr/bin/env python3
"""Add gaming cafe photos to all clubs in Supabase."""
import subprocess, json, random

TOKEN = "sbp_856e4068bebec50c18b41dac00fd30695444208b"
PROJECT = "rizyqzjszaknzjboooow"

# Gaming/esports themed Unsplash photos
vip_photos = [
    "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&q=80",
    "https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=800&q=80",
    "https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=800&q=80",
    "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=800&q=80",
    "https://images.unsplash.com/photo-1625805866449-3589fe3f71a3?w=800&q=80",
    "https://images.unsplash.com/photo-1600861194942-f883de0dfe96?w=800&q=80",
    "https://images.unsplash.com/photo-1598550476439-6847785fcea6?w=800&q=80",
    "https://images.unsplash.com/photo-1560253023-3ec5d502959f?w=800&q=80",
    "https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=800&q=80",
    "https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=800&q=80",
]

standard_photos = [
    "https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800&q=80",
    "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&q=80",
    "https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&q=80",
    "https://images.unsplash.com/photo-1547394765-185e1e68f34e?w=800&q=80",
    "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=800&q=80",
    "https://images.unsplash.com/photo-1592155931584-901ac15763e4?w=800&q=80",
    "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&q=80",
    "https://images.unsplash.com/photo-1603481588273-2f908a9a7a1b?w=800&q=80",
    "https://images.unsplash.com/photo-1586182987320-4f376d39d787?w=800&q=80",
    "https://images.unsplash.com/photo-1558742619-fd82741daa9e?w=800&q=80",
]

basic_photos = [
    "https://images.unsplash.com/photo-1580327344181-c131031e4adc?w=800&q=80",
    "https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=800&q=80",
    "https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=800&q=80",
    "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&q=80",
    "https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?w=800&q=80",
    "https://images.unsplash.com/photo-1547394765-185e1e68f34e?w=800&q=80",
    "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800&q=80",
    "https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800&q=80",
]

def run_sql(sql):
    result = subprocess.run(
        ["curl", "-s", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
         "-H", f"Authorization: Bearer {TOKEN}",
         "-H", "Content-Type: application/json",
         "-d", json.dumps({"query": sql})],
        capture_output=True, text=True
    )
    return result.stdout

# Get all clubs
clubs_raw = run_sql("SELECT id, name, tier FROM clubs ORDER BY name")
clubs = json.loads(clubs_raw)
print(f"Found {len(clubs)} clubs")

# Update each club individually for simplicity
success = 0
for i, club in enumerate(clubs):
    cid = club['id']
    tier = club['tier']
    name = club['name']

    if tier == 'vip':
        pool = vip_photos
        count = 5
    elif tier == 'standard':
        pool = standard_photos
        count = 4
    else:
        pool = basic_photos
        count = 3

    selected = random.sample(pool, min(count, len(pool)))
    # PostgreSQL text array literal: ARRAY['url1','url2','url3']
    array_items = ", ".join(f"'{url}'" for url in selected)
    sql = f"UPDATE clubs SET photos = ARRAY[{array_items}] WHERE id = '{cid}'"

    result = run_sql(sql)
    if "error" in result.lower():
        print(f"  ERROR [{name}]: {result[:150]}")
    else:
        success += 1

    if (i + 1) % 10 == 0:
        print(f"  Progress: {i+1}/{len(clubs)}")

print(f"\nUpdated {success}/{len(clubs)} clubs with photos")

# Verify
verify = run_sql("SELECT name, tier, array_length(photos, 1) as cnt FROM clubs ORDER BY cnt DESC NULLS LAST LIMIT 5")
print(f"\nVerification: {verify}")
